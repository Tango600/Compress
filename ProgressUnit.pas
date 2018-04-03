unit ProgressUnit;

// Модуль отображения прогреса в терминале
interface

uses SysUtils;

Procedure InitProgress(Size: Int64);
Procedure SetProgress(Position: Int64);

Var
  NoProgress: Boolean;

implementation

const
  Long=50;
  EmptySection='-';
  FillSection='#';

Var
  P, S, L, R, Price: Real;
  Step: Integer;

Procedure InitProgress(Size: Int64);
Var
  i: Word;
Begin
  If not NoProgress then
  Begin
    Step:=Size div 100;
    S:=Size;
    L:=Long;
    Price:=L/S;
    WriteLn;
    WriteLn;
    For i:=1 to Long do
      Write(EmptySection);
    Write(#13);
  End;
End;

Procedure SetProgress(Position: Int64);
Var
  pp, i: Word;
Begin
  If not NoProgress then
    If (Position mod Step)=0 then
    Begin
      P:=Position;
      pp:=Round(Price*P);
      For i:=1 to pp do
        Write(FillSection);
      For i:=1 to Long-pp do
        Write(EmptySection);
      Write(' ');
      R:=(P/S)*100;
      pp:=Round(R);
      Write(IntToStr(pp)+' %  ');
      Write(#13);
    End;
End;

Begin
  NoProgress:=False;
end.
