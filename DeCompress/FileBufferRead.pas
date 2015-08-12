Unit FileBuffer;

// Модуль буферизированного ввода/вывода, реально ускаряет файловые
// операции из за ввода/вывода в память, а только потом, как буфер
// переполнится, в файл.

interface

uses
  Classes, SysUtils;

Procedure BeginRead;

Function GetFSize(Var F: TMemoryStream): Int64;
Function SeekBuffer(Var F: TMemoryStream; SeekPos: Int64): Byte;
Function GetBytes(var F: TMemoryStream): Byte;
Procedure ResetBuffer(Var F: TMemoryStream);
Procedure OutputBytes(Var F: TMemoryStream; B: Byte);
Function BitRead(Var F: TMemoryStream; NumBits: Byte): Word;

Var
  ArcFile, DataFile: TMemoryStream;
  FSize: Int64;

implementation

Const
  BufLength=64*1024;

Var
  ReadCounterBit: Byte;
  BufsCount, OutBufPos, ReadBitsBuffer: Cardinal;
  FPos, FOffset, ArcSize, DataPos: Int64;
  InBuffer, OutBuffer: Array of Byte;
  

Procedure GetBuff(var F: TMemoryStream);
Var
  CountBytes: Cardinal;
Begin
  If FSize>=FPos then
  Begin
    If BufsCount=0 then
    Begin
      FPos:=F.Position;
      FOffset:=F.Position;
    End;
    F.Seek(((FPos div BufLength)*BufLength)+FOffset, 0);
    CountBytes:=F.Read(InBuffer[0], BufLength);
    Inc(FPos, CountBytes);
    BufsCount:=(FPos div BufLength)+((BufLength+(FPos mod BufLength)-1) div BufLength);
  End;
End;

Function GetBytes(var F: TMemoryStream): Byte;
Begin
  GetBytes:=0;
  If BufsCount=0 then
  Begin
    GetBuff(F);
    DataPos:=0;
  End;

  If ((FPos div BufLength)+1)<>BufsCount then
    GetBuff(F);
  If DataPos<=FSize then
  Begin
    GetBytes:=InBuffer[DataPos-((BufsCount-1)*BufLength)];
    Inc(DataPos);
  End;
End;

Procedure ResetBuffer(Var F: TMemoryStream);
Begin
  F.Write(OutBuffer[0], OutBufPos);
  OutBufPos:=0;
End;

Procedure OutputBytes(Var F: TMemoryStream; B: Byte);
Begin
  OutBuffer[OutBufPos]:=B;
  Inc(ArcSize);
  Inc(OutBufPos);
  If OutBufPos=BufLength then
    ResetBuffer(F);
End;

// ======================Bit read==========================================

Function BitRead(Var F: TMemoryStream; NumBits: Byte): Word;
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

Function SeekBuffer(Var F: TMemoryStream; SeekPos: Int64): Byte;
Var
  B: Byte;
  OldPos: Int64;
Begin
  If (((BufsCount-1)*BufLength)<=SeekPos)and(((BufsCount)*BufLength)>=SeekPos) then
    Result:=InBuffer[SeekPos-((BufsCount-1)*BufLength)]
  Else
  Begin
    // не повезло не попали в буфер

    OldPos:=F.Position;
    F.Seek(SeekPos, 0);
    F.Read(B, 1);
    F.Seek(OldPos, 0);
    Result:=B;
  End;
End;

////////////////////////////////////////////////////////////////////

Procedure BeginRead;
Begin
  BufsCount:=0;
  FPos:=0;
  FOffset:=0;
  ReadBitsBuffer:=0;
  ReadCounterBit:=0;
End;

Function GetFSize(Var F: TMemoryStream): Int64;
Begin
  Result:=F.Size;
End;

Begin
  SetLength(OutBuffer, BufLength+1);
  SetLength(InBuffer, BufLength+1);
End.
