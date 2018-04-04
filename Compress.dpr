program Compress;
{$I DefineType.pas}
{$APPTYPE CONSOLE}

uses
{$IFDEF StreamType}
  Classes,
{$ENDIF}
{$IFDEF MSWINDOWS}Windows, {$ENDIF}
  SysUtils, FileBuffer, CompressUnit, ProgressUnit;

Const
  Version='2.4.2';
  SignatureSize=3;
  Signature: Array [1..4] of Byte=($50, $41, $47, $21);
  fpcVersion={$I %FPCVERSION%};

Var
  k: Byte;
  SignatureOnly, Raw:Boolean;
  i: Word;
  Time, ArcFileSize, DataFileSize: Cardinal;
  InFileName, OutFileName, OutFileName2: String;

Function UpTime: Cardinal;
Begin
  Result:={$IFDEF MSWINDOWS}GetTickCount64
{$ELSE}
    ((StrToInt(FormatDateTime('H', Time))*3600+StrToInt(FormatDateTime('N', Time))*60+
    StrToInt(FormatDateTime('S', Time)))*1000)+StrToInt(FormatDateTime('Z', Time));
{$ENDIF};
End;

Procedure WriteInfo(Time: Cardinal; ArcSize, FSize: Int64);
var
  sp: Cardinal;
Begin
  WriteLn;
  WriteLn;
  If Time<2500 then
    WriteLn('Time: '+IntToStr(Time)+' ms.')
  Else If (Time>2500)and(Time<120000) then
    WriteLn('Time: '+IntToStr(Time div 1000)+' s. '+IntToStr(Time mod 1000)+' ms.')
  Else If (Time>=120000)and(Time<3600000) then
    WriteLn('Time: '+IntToStr(Time div 60000)+' m. '+IntToStr((Time mod 60000)div 1000)+' s.')
  Else
    WriteLn('Time: '+IntToStr(Time div 3600000)+' h. '+IntToStr((Time mod 3600000)div 60000)+' m.');

  sp:=(FSize div 1024) div (Time div 1000);
  If sp<2500 then
    WriteLn('Speed: '+IntToStr(sp)+' Kibytes/s')
  Else
    WriteLn('Speed: '+IntToStr(sp div 1024)+' Mibytes/s');

  WriteLn('Ratio: '+FloatToStr(Round((ArcSize/FSize)*1000)/1000));
  If ArcSize<100000 then
    WriteLn('Arc Size: '+IntToStr(ArcSize)+' bytes.')
  Else If (ArcSize>100000)and(ArcSize<1200000) then
    WriteLn('Arc Size: '+IntToStr(ArcSize div 1024)+' Kib.')
  Else If (ArcSize>1200000)and(ArcSize<1073741824) then
    WriteLn('Arc Size: '+IntToStr(ArcSize div(1024*1024))+' Mib.')
  Else If ArcSize>1073741824 then
    WriteLn('Arc Size: '+IntToStr(ArcSize div(1024*1024*1024))+' Gib. '+
      IntToStr(ArcSize mod(1024*1024*1024)div(1024*1024))+' Mib.');
End;


// ====================Main program===========================

begin
  If (ParamStr(1)='/?')or(ParamStr(1)='') then
  Begin
{$IFDEF FPC}
    WriteLn('FPC v.'+fpcVersion);
{$ENDIF}
    WriteLn('Compress v.'+Version);
    WriteLn(ParamStr(0)+' c|d InputFile.ext [OutputFile.ext]');
    WriteLn(' c compress');
    WriteLn(' d decompress');
    WriteLn;
    WriteLn(' switches:');
    WriteLn(' -b VALUE max bits');
    WriteLn(' -t test mode');
    WriteLn(' -o output file name');
    WriteLn(' -p without progress bar');
    WriteLn(' -r raw mode');
    WriteLn(' -s write signature only');
    ReadLn;
    Halt;
  End;
  WriteMode:=1;
  MaxWordSize:=16;
  SignatureOnly:=False;
  Raw:=False;
  For i:=1 to ParamCount do
  Begin
    If ParamStr(i)='-b' then
      MaxWordSize:=StrToInt(ParamStr(i+1));
    If ParamStr(i)='-t' then
      WriteMode:=0;
    If ParamStr(i)='-o' then
      OutFileName:=ParamStr(i+1);
    If ParamStr(i)='-p' then
      NoProgress:=True;
    If ParamStr(i)='-s' then
      SignatureOnly:=True;
    If ParamStr(i)='-r' then
      Raw:=True;
  End;

  InFileName:=ParamStr(2);

  If LowerCase(ParamStr(1))='c' then
  Begin
    If FileExists(InFileName) then
    Begin
      WriteLn;
      WriteLn('Compressing...  '+InFileName);
{$IFDEF StreamType}
      DataFile:=TFileStream.Create(InFileName, fmOpenRead or fmShareDenyWrite);
{$ENDIF}
{$IFDEF FileType}
      AssignFile(DataFile, InFileName);
      ReSet(DataFile);
{$ENDIF}
      If WriteMode=1 then
      Begin
        If not Raw then
          For i:=1 to SignatureSize do
            BitWrite(ArcFile, Signature[i], 8);

        OutFileName2:=ExtractFileName(InFileName);
        If not Raw then
        If not SignatureOnly then
        Begin
          For i:=1 to Length(OutFileName2) do
            BitWrite(ArcFile, Ord(OutFileName2[i]), 8);
          BitWrite(ArcFile, $2A, 8);
        End;

        If OutFileName='' then
        Begin
          OutFileName:=ExtractFileName(InFileName);
          i:=Length(OutFileName);
          While (OutFileName[i]<>'.')and(i>1) do
            Dec(i);
          If i=1 then
            i:=Length(OutFileName)+1;
          OutFileName:=Copy(OutFileName, 1, i-1);
          OutFileName:=OutFileName+'.z';
        End;

{$IFDEF StreamType}
        ArcFile:=TFileStream.Create(OutFileName, fmCreate);
{$ENDIF}
{$IFDEF FileType}
        AssignFile(ArcFile, OutFileName);
        ReWrite(ArcFile);
{$ENDIF}
      End;

      Time:=UpTime;
      CompressProc(DataFile, ArcFile);
      Time:=UpTime-Time+1;

      ArcFileSize:=GetFSize(ArcFile);
      DataFileSize:=GetFSize(DataFile);
      WriteInfo(Time, ArcFileSize, DataFileSize);

{$IFDEF StreamType}
      DataFile.Free;
{$ENDIF}
{$IFDEF FileType}
      CloseFile(DataFile);
{$ENDIF}
      If WriteMode=1 then
{$IFDEF StreamType}
        ArcFile.Free;
{$ENDIF}
{$IFDEF FileType}
      CloseFile(ArcFile);
{$ENDIF}
    End;
  End;

  If LowerCase(ParamStr(1))='d' then
  Begin
    If Pos('.z', InFileName)=0 then
      InFileName:=InFileName+'.z';
    If FileExists(InFileName) then
    Begin
{$IFDEF StreamType}
      ArcFile:=TFileStream.Create(InFileName, 0);
      FSize:=GetFSize(ArcFile);
{$ENDIF}
{$IFDEF FileType}
      AssignFile(ArcFile, InFileName);
      ReSet(ArcFile);
      FSize:=FileSize(ArcFile);
{$ENDIF}
      If not Raw then
      Begin
        k:=0;
        For i:=1 to SignatureSize do
          If BitRead(ArcFile, 8)=Signature[i] then
            Inc(k);
      End
      Else
        k:=SignatureSize;

      If k=SignatureSize then
      Begin
        If not Raw then
        If not SignatureOnly then
        Begin
          OutFileName2:='';
          Repeat
            k:=BitRead(ArcFile, 8);
            OutFileName2:=OutFileName2+Chr(k);
          Until k=$2A;
        End;

        If OutFileName='' then
        Begin
          OutFileName:=OutFileName2;
          Delete(OutFileName, Length(OutFileName), 1);
        End;

        If WriteMode=1 then
        Begin
{$IFDEF StreamType}
          DataFile:=TFileStream.Create(OutFileName, fmCreate);
{$ENDIF}
{$IFDEF FileType}
          AssignFile(DataFile, OutFileName);
          ReWrite(DataFile);
{$ENDIF}
        End;

        DeCompressProc(ArcFile, DataFile);

{$IFDEF StreamType}
        ArcFile.Free;
{$ENDIF}
{$IFDEF FileType}
        CloseFile(ArcFile);
{$ENDIF}
      End;
      If WriteMode=1 then
{$IFDEF StreamType}
        DataFile.Free;
{$ENDIF}
{$IFDEF FileType}
      CloseFile(DataFile);
{$ENDIF}
    End;
  End;

  If LowerCase(ParamStr(1))='l' then
  Begin
    If Pos('.z', InFileName)=0 then
      InFileName:=InFileName+'.z';
    If FileExists(InFileName) then
    Begin
{$IFDEF StreamType}
      ArcFile:=TFileStream.Create(InFileName, 0);
      FSize:=GetFSize(ArcFile);
{$ENDIF}
{$IFDEF FileType}
      AssignFile(ArcFile, InFileName);
      ReSet(ArcFile);
      FSize:=FileSize(ArcFile);
{$ENDIF}
      k:=0;
      For i:=1 to SignatureSize do
        If BitRead(ArcFile, 8)=Signature[i] then
          Inc(k);

      If k=SignatureSize then
      Begin
        OutFileName:='';
        Repeat
          k:=BitRead(ArcFile, 8);
          OutFileName:=OutFileName+Chr(k);
        Until k=$2A;

        Delete(OutFileName, Length(OutFileName), 1);

        WriteLn('File name: '+OutFileName);
      End;
{$IFDEF StreamType}
      ArcFile.Free;
{$ENDIF}
{$IFDEF FileType}
      CloseFile(ArcFile);
{$ENDIF}
    End;
  End;
end.
