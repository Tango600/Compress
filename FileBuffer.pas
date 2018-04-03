Unit FileBuffer;
{$I DefineType.pas}
// Модуль буферизированного ввода/вывода, реально ускаряет файловые
// операции из за ввода/вывода в память, а только потом, как буфер
// переполнится, в файл.

interface

uses
{$IFDEF StreamType}
  Classes,
{$ENDIF}
  SysUtils;

Type
{$IFDEF StreamType}
  TByteFile=TFileStream;
{$ENDIF}
{$IFDEF FileType}
  TByteFile=File of Byte;
{$ENDIF}
Procedure BeginRead;
Procedure BeginWrite;

Procedure OpenFile(var F: TByteFile; FileName:String);
Procedure CloseFile(var F: TByteFile);
Function GetFSize(Var F: TByteFile): Int64;
Function SeekBuffer(Var F: TByteFile; SeekPos: Int64): Byte;
Function GetBytes(var F: TByteFile): Byte;
Procedure ResetBuffer(Var F: TByteFile);
Procedure OutputBytes(Var F: TByteFile; B: Byte);
Procedure BitWrite(Var F: TByteFile; Num: Word; NumBits: Byte);
Function BitRead(Var F: TByteFile; NumBits: Byte): Word;
Procedure EndBitWrite(Var F: TByteFile);

Function ReadDWord(Var F: TByteFile): Cardinal;
Function ReadWord(Var F: TByteFile): Word;

Procedure WriteDWord(Var F: TByteFile; DW: Cardinal);
Procedure WriteWord(Var F: TByteFile; W: Word);

Var
  ArcFile, DataFile: TByteFile;
  WriteMode: Byte;
  ArcSize, DataPos, FSize: Int64;

implementation

Const
  BufLength=1024*1024;

Var
  ReadCounterBit, WriteCounterBit: Byte;
  BufsCount, OutBufPos, ReadBitsBuffer, WriteBitsBuffer: Cardinal;

  FPos, FOffset: Int64;

  DWordRec: Record LowLo, LowHi, HiLo, HiHi: Byte;
End;

DWordData:
Cardinal Absolute DWordRec;

WordRec:
Record Low, Hi: Byte;
End;

WordData:
Cardinal Absolute WordRec;

InBuffer:Array of Byte;
OutBuffer:Array of Byte;

Procedure OpenFile(var F: TByteFile; FileName:String);
Begin
{$IFDEF StreamType}
  F:=TByteFile.Create(FileName, fmCreate);
{$ENDIF}
{$IFDEF FileType}
  AssignFile(F, FileName);
  ReWrite(F);
{$ENDIF}
End;

Procedure CloseFile(var F: TByteFile);
Begin
{$IFDEF StreamType}
  F.Free;
{$ENDIF}
{$IFDEF FileType}
  CloseFile(F);
{$ENDIF}
End;

Procedure GetBuff(var F: TByteFile);
Var
  CountBytes: Cardinal;
Begin
  If FSize>=FPos then
  Begin
    If BufsCount=0 then
    Begin
{$IFDEF FileType}
      FPos:=FilePos(F);
{$ENDIF}
{$IFDEF StreamType}
      FPos:=F.Position;
{$ENDIF}
      FOffset:=FPos;
    End;
{$IFDEF FileType}
    Seek(F, ((FPos div BufLength)*BufLength)+FOffset);
    BlockRead(F, InBuffer[0], BufLength, CountBytes);
{$ENDIF}
{$IFDEF StreamType}
    F.Seek(((FPos div BufLength)*BufLength)+FOffset, 0);
    CountBytes:=F.Read(InBuffer[0], BufLength);
{$ENDIF}
    Inc(FPos, CountBytes);
    BufsCount:=(FPos div BufLength)+((BufLength+(FPos mod BufLength)-1) div BufLength);
  End;
End;

Function GetBytes(var F: TByteFile): Byte;
Begin
  GetBytes:=0;
  If BufsCount=0 then
  Begin
    GetBuff(F);
    DataPos:=0;
  End;

  If ((DataPos div BufLength)+1)<>BufsCount then
    GetBuff(F);
  If DataPos<=FSize then
  Begin
    GetBytes:=InBuffer[DataPos-((BufsCount-1)*BufLength)];
    Inc(DataPos);
  End;
End;

Procedure ResetBuffer(Var F: TByteFile);
Begin
  If WriteMode=1 then
{$IFDEF StreamType}
    F.Write(OutBuffer[0], OutBufPos);
{$ENDIF}
{$IFDEF FileType}
    BlockWrite(F, OutBuffer[0], OutBufPos);
{$ENDIF}
  OutBufPos:=0;
End;

Procedure OutputBytes(Var F: TByteFile; B: Byte);
Begin
  OutBuffer[OutBufPos]:=B;
  Inc(ArcSize);
  Inc(OutBufPos);
  If OutBufPos=BufLength then
    ResetBuffer(F);
End;

// ======================Bit read==========================================

Function BitRead(Var F: TByteFile; NumBits: Byte): Word;
var
  B: Word;
begin
  { Пока в буфере не хватает бит - читаем их из файла }
  While ReadCounterBit<NumBits do
  Begin
    B:=GetBytes(F);
    ReadBitsBuffer:=ReadBitsBuffer or(B shl ReadCounterBit);
    { Добавляем его в буфер }
    Inc(ReadCounterBit, 8);
  End;
  BitRead:=Word(ReadBitsBuffer and((1 shl NumBits)-1));
  { Получаем из буфера нужное кол-во бит }
  ReadBitsBuffer:=ReadBitsBuffer shr NumBits;
  { Отчищаем буфер от выданных бит }
  Dec(ReadCounterBit, NumBits);
end;

// ======================Bit read End======================================
// ======================Bit Write=========================================

Procedure BitWrite(Var F: TByteFile; Num: Word; NumBits: Byte);
Var
  B: Byte;
  BitBuffer: Cardinal;
begin
  If WriteMode=1 then
  Begin
  BitBuffer:=Num;
  WriteBitsBuffer:=WriteBitsBuffer or(BitBuffer shl WriteCounterBit);
  { Добавляем в буфер новые биты }
  Inc(WriteCounterBit, NumBits);
  While (WriteCounterBit>=8) do
  Begin
    B:=Byte(WriteBitsBuffer and $FF); { Получаем первый байт из буфера }
    OutputBytes(F, B);
    WriteBitsBuffer:=WriteBitsBuffer shr 8;
    { Отчищам буфер от записанных бит }
    Dec(WriteCounterBit, 8);
  End;
  End;
end;

Procedure EndBitWrite(Var F: TByteFile);
Var
  B: Byte;
begin
  If WriteMode=1 then
  Begin
  If (WriteCounterBit>0) then
  Begin
    B:=WriteBitsBuffer;
    OutputBytes(F, B);
    WriteCounterBit:=0;
    WriteBitsBuffer:=0;
  End;
  BufsCount:=0;
  FPos:=0;
  End;
end;

// ====================Bit Write End=======================================

Function SeekBuffer(Var F: TByteFile; SeekPos: Int64): Byte;
Var
  B: Byte;
  OldPos: Int64;
Begin
  If (((BufsCount-1)*BufLength)<=SeekPos)and(((BufsCount)*BufLength)>=SeekPos) then
    Result:=InBuffer[SeekPos-((BufsCount-1)*BufLength)]
  Else
  Begin
    // не повезло не попали в буфер

{$IFDEF StreamType}
    OldPos:=F.Position;
    F.Seek(SeekPos, 0);
    F.Read(B, 1);
    F.Seek(OldPos, 0);
{$ENDIF}
{$IFDEF FileType}
    OldPos:=FilePos(F);
    Seek(F, SeekPos);
    BlockRead(F, B, 1);
    Seek(F, OldPos);
{$ENDIF}
    Result:=B;
  End;
End;

Procedure WriteWord(Var F: TByteFile; W: Word);
Begin
  WordData:=W;
  BitWrite(F, WordRec.Low, 8);
  BitWrite(F, WordRec.Hi, 8);
End;

Procedure WriteDWord(Var F: TByteFile; DW: Cardinal);
Begin
  DWordData:=DW;
  BitWrite(F, DWordRec.LowLo, 8);
  BitWrite(F, DWordRec.LowHi, 8);
  BitWrite(F, DWordRec.HiLo, 8);
  BitWrite(F, DWordRec.HiHi, 8);
End;

Function ReadWord(Var F: TByteFile): Word;
Begin
  WordRec.Low:=BitRead(F, 8);
  WordRec.Hi:=BitRead(F, 8);
  Result:=WordData;
End;

Function ReadDWord(Var F: TByteFile): Cardinal;
Begin
  DWordRec.LowLo:=BitRead(F, 8);
  DWordRec.LowHi:=BitRead(F, 8);
  DWordRec.HiLo:=BitRead(F, 8);
  DWordRec.HiHi:=BitRead(F, 8);
  Result:=DWordData;
End;

/// /////////////////////////////////////////////////////////////////

Procedure BeginRead;
Begin
  BufsCount:=0;
  FPos:=0;
  FOffset:=0;
  ReadBitsBuffer:=0;
  ReadCounterBit:=0;
End;

Procedure BeginWrite;
Begin
  WriteCounterBit:=0;
  WriteBitsBuffer:=0;
End;

Function GetFSize(Var F: TByteFile): Int64;
Begin
{$IFDEF StreamType}
  Result:=F.Size;
{$ENDIF}
{$IFDEF FileType}
  Result:=FileSize(F);
{$ENDIF}
  FSize:=Result;
End;

Begin
  SetLength(OutBuffer, BufLength+1);
  SetLength(InBuffer, BufLength+1);
  BeginRead;
End.
