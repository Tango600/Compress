Unit DeCompressUnit;

// Модуль LZW распаковщика
// требует модуля FileBuffer
interface

uses SysUtils, Classes, Windows, FileBufferRead;

Procedure DecompressProc(Var Arc, Data: TMemoryStream);

implementation

Const
  MaxWordSize=16;
  TopChar=255;
  ClearDictValue=256;
  FreezDict=ClearDictValue+1;
  StepWordLength=ClearDictValue+2;
  EndOfStream=ClearDictValue+3;

Type
  DictR=Record
    Up, Left, Right, Code: Word;
    AddChar: Byte;
  End;

  TDecodeBuffer=Array of Byte;

Var
  Overflow: Boolean;
  BitSize, AddChar: Byte;
  CurMaxCode, DictPos, MaxDictSize: Word;
  DecodeBufferSize: Cardinal;
  Dict: Array of DictR;

  DecodeBuffer: TDecodeBuffer;

Function GetMaxDictSize(PowNum: Byte): Word;
const
  BaseNum=2;
var
  i: Byte;
  s: Cardinal;
begin
  s:=1;
  For i:=1 to PowNum do
    s:=s*BaseNum;
  Dec(s);
  GetMaxDictSize:=s;
end;

Procedure InitDict;
Begin
  MaxDictSize:=GetMaxDictSize(MaxWordSize);
  SetLength(Dict, MaxDictSize);
End;

// =========================Dictionary Begin==================================

Procedure AddNode(s: Word; C: Byte);
Var
  dc: Word;
Begin
  If DictPos<MaxDictSize then
  Begin
    If Dict[s].Up=ClearDictValue then
    Begin
      // Никого нет на этой ноде
      Dict[s].Up:=DictPos;
      Dict[DictPos].Up:=ClearDictValue;
      Dict[DictPos].Left:=ClearDictValue;
      Dict[DictPos].Right:=ClearDictValue;
      Dict[DictPos].Code:=s;
      Dict[DictPos].AddChar:=C;
    End
    Else
    Begin
      // Кто-то живёт тут
      If C>Dict[Dict[s].Up].AddChar then
      Begin
        // Смотрим куда податься
        // Вперёд
        dc:=Dict[s].Up;
        While Dict[dc].Right<>ClearDictValue do
          dc:=Dict[dc].Right;

        Dict[dc].Right:=DictPos;
        Dict[DictPos].Up:=ClearDictValue;
        Dict[DictPos].Left:=DictPos;
        Dict[DictPos].Right:=ClearDictValue;
        Dict[DictPos].Code:=s;
        Dict[DictPos].AddChar:=C;
      End
      Else
      Begin
        // Назад
        dc:=Dict[s].Up;
        While Dict[dc].Left<>ClearDictValue do
          dc:=Dict[dc].Left;

        Dict[dc].Left:=DictPos;
        Dict[DictPos].Up:=ClearDictValue;
        Dict[DictPos].Left:=ClearDictValue;
        Dict[DictPos].Right:=DictPos;
        Dict[DictPos].Code:=s;
        Dict[DictPos].AddChar:=C;
      End;
    End;
    Inc(DictPos);
  End;
End;

Function FindNode(s: Word; C: Byte): LongInt;
Var
  dc: Word;
Begin
  Result:= - 1;
  If Dict[s].Up<>ClearDictValue then
  Begin
    dc:=Dict[s].Up;
    If Dict[dc].AddChar<>C then
    Begin
      If Dict[dc].AddChar<C then
      Begin
        dc:=Dict[dc].Right;
        While dc<>ClearDictValue do
        Begin
          If Dict[dc].AddChar=C then
          Begin
            FindNode:=dc;
            Exit;
          End;
          dc:=Dict[dc].Right;
        End;
      End;
      If Dict[dc].AddChar>C then
      Begin
        dc:=Dict[dc].Left;
        While dc<>ClearDictValue do
        Begin
          If Dict[dc].AddChar=C then
          Begin
            FindNode:=dc;
            Exit;
          End;
          dc:=Dict[dc].Left;
        End;
      End;
    End
    Else
      FindNode:=dc;
  End;
End;

Procedure InitCoder;
Var
  i: Word;
Begin
  BitSize:=9;
  Overflow:=False;
  CurMaxCode:=GetMaxDictSize(BitSize);
  For i:=0 to MaxDictSize-1 do
  Begin
    Dict[i].Code:=0;
    Dict[i].AddChar:=0;

    Dict[i].Up:=ClearDictValue;
    Dict[i].Left:=ClearDictValue;
    Dict[i].Right:=ClearDictValue;
  End;
  For i:=0 to TopChar do
  Begin
    Dict[i].Code:=ClearDictValue;
    Dict[i].AddChar:=i;
  End;
  DictPos:=EndOfStream+1;
End;

// ======================Dictionary End=====================================

Procedure OutPutDecodeBuffer(Var F: TMemoryStream; Buff: TDecodeBuffer);
Var
  le, i: Cardinal;
Begin
  le:=Length(Buff);
  For i:=0 to le-1 do
    OutputBytes(F, Buff[i]);
End;

Procedure DecodeString(DeCode: Word);
Var
  dc: Word;
  ReversC, ForwC: Cardinal;
  DS: TDecodeBuffer;
Begin
  dc:=DeCode;
  DecodeBufferSize:=0;
  Repeat
    SetLength(DS, DecodeBufferSize+1);
    DS[DecodeBufferSize]:=Dict[dc].AddChar;
    dc:=Dict[dc].Code;
    Inc(DecodeBufferSize);
  Until dc=ClearDictValue;
  SetLength(DecodeBuffer, DecodeBufferSize);
  ReversC:=0;
  For ForwC:=DecodeBufferSize-1 downto 0 do
  Begin
    DecodeBuffer[ReversC]:=DS[ForwC];
    Inc(ReversC);
  End;
End;

Procedure DecompressProc(Var Arc, Data: TMemoryStream);
Var
  NewCode, OldCode: Word;
Begin
  BeginRead;
  InitDict;
  NewCode:=0;
  InitCoder;

  FSize:=GetFSize(Arc);

  OldCode:=BitRead(Arc, BitSize);
  OutputBytes(Data, OldCode);

  AddChar:=Byte(OldCode);

  While NewCode<>EndOfStream do
  Begin
    NewCode:=BitRead(Arc, BitSize);

    Case NewCode of
    EndOfStream:
    break;

    ClearDictValue:
    Begin
      InitCoder;
      OldCode:=BitRead(Arc, BitSize);
      AddChar:=Byte(OldCode);
      NewCode:=BitRead(Arc, BitSize);
    End;

    StepWordLength:
    Begin
      Inc(BitSize);
      CurMaxCode:=GetMaxDictSize(BitSize);
      NewCode:=BitRead(Arc, BitSize);
    End;
    End;

    If DictPos<=NewCode then
    Begin
      DecodeString(OldCode);
      Inc(DecodeBufferSize);
      SetLength(DecodeBuffer, DecodeBufferSize);
      DecodeBuffer[DecodeBufferSize-1]:=AddChar;
    End
    Else
      DecodeString(NewCode);

    OutPutDecodeBuffer(Data, DecodeBuffer);

    AddChar:=DecodeBuffer[0];

    AddNode(OldCode, AddChar);

    OldCode:=NewCode;
  End;

  ResetBuffer(Data);
End;

end.
