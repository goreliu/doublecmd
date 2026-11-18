{
   Double commander
   -------------------------------------------------------------------------
   AnyCmd wlx plugin - runs a configured command for the selected file and
   displays the captured output as UTF-8 text.

   anycmd.ini example:
     [AnyCmd]
     DetectString=TRUE
     command=c:\Windows\System32\cmd.exe /c echo "%s"
     Stream=3

   Stream bit mask:
     1 = stdout
     2 = stderr
     3 = stdout and stderr
}

library AnyCmd;

{$mode objfpc}{$H+}

uses
  SysUtils, StrUtils, Windows, Messages, WlxPlugin;

const
  EDIT_CLASS = 'Edit';
  DEFAULT_FONT_NAME: PWideChar = 'Segoe UI';
  DEFAULT_FONT_SIZE = 11;
  INI_SECTION = 'AnyCmd';
  INI_COMMAND = 'command';
  INI_DETECT = 'DetectString';
  INI_STREAM = 'Stream';
  BUFFER_SIZE = 8192;

var
  GDetectString: AnsiString = '*';

function GetModuleIniPath: UnicodeString;
var
  ABuf: array[0..MAX_PATH - 1] of WideChar;
  ALen: DWORD;
begin
  ABuf[0] := #0;
  ALen := GetModuleFileNameW(HInstance, ABuf, MAX_PATH);
  if ALen > 0 then
    Result := IncludeTrailingPathDelimiter(ExtractFilePath(UnicodeString(ABuf))) + 'anycmd.ini'
  else
    Result := 'anycmd.ini';
end;

function GetIniPath: UnicodeString;
begin
  Result := GetModuleIniPath;
end;

function ReadIniW(const AKey, ADefault: UnicodeString): UnicodeString;
var
  ABuf: array[0..32767] of WideChar;
begin
  ABuf[0] := #0;
  GetPrivateProfileStringW(INI_SECTION, PWideChar(AKey), PWideChar(ADefault),
                           ABuf, Length(ABuf), PWideChar(GetIniPath));
  Result := UnicodeString(ABuf);
end;

function ReadIniInt(const AKey: UnicodeString; ADefault: Integer): Integer;
begin
  Result := GetPrivateProfileIntW(INI_SECTION, PWideChar(AKey), ADefault, PWideChar(GetIniPath));
end;

function ReplaceToken(const ATemplate, AToken, AValue: UnicodeString): UnicodeString;
var
  I, J: Integer;
begin
  Result := '';
  I := 1;
  J := PosEx(AToken, ATemplate, I);
  while J > 0 do
  begin
    Result := Result + Copy(ATemplate, I, J - I) + AValue;
    I := J + Length(AToken);
    J := PosEx(AToken, ATemplate, I);
  end;
  Result := Result + Copy(ATemplate, I, MaxInt);
end;

function Utf8ToUnicode(const AText: RawByteString): UnicodeString;
var
  WideLen: Integer;
begin
  Result := '';
  if Length(AText) = 0 then Exit;

  WideLen := MultiByteToWideChar(CP_UTF8, 0, PAnsiChar(AText), Length(AText), nil, 0);
  if WideLen <= 0 then Exit;

  SetLength(Result, WideLen);
  if MultiByteToWideChar(CP_UTF8, 0, PAnsiChar(AText), Length(AText),
                         PWideChar(Result), WideLen) <= 0 then
    Result := '';
end;

function OpenNullDevice: THandle;
begin
  Result := CreateFileW('NUL', GENERIC_WRITE, FILE_SHARE_READ or FILE_SHARE_WRITE,
                        nil, OPEN_EXISTING, 0, 0);
end;

function RunCommand(const FileToLoad: PWideChar; out AText: UnicodeString): Boolean;
var
  ACommandLine, ACmd: UnicodeString;
  AStartup: TStartupInfoW;
  AProcess: TProcessInformation;
  AReadPipe, AWritePipe, ANullHandle: THandle;
  ASecurity: TSecurityAttributes;
  ABuffer: array[0..BUFFER_SIZE - 1] of Byte;
  ABytesRead: DWORD;
  AOutput: RawByteString;
  AChunk: RawByteString;
  AStreamNo: Integer;
  AUseStdOut, AUseStdErr: Boolean;
begin
  Result := False;
  AText := '';

  ACmd := ReadIniW(INI_COMMAND, '');
  if ACmd = '' then Exit;

  AStreamNo := ReadIniInt(INI_STREAM, 3);
  AUseStdOut := (AStreamNo and 1) <> 0;
  AUseStdErr := (AStreamNo and 2) <> 0;
  if not AUseStdOut and not AUseStdErr then Exit;

  ACommandLine := ReplaceToken(ACmd, '%s', UnicodeString(FileToLoad));

  ZeroMemory(@ASecurity, SizeOf(ASecurity));
  ASecurity.nLength := SizeOf(ASecurity);
  ASecurity.bInheritHandle := True;

  if not CreatePipe(AReadPipe, AWritePipe, @ASecurity, 0) then Exit;
  ANullHandle := OpenNullDevice;
  try
    ZeroMemory(@AStartup, SizeOf(AStartup));
    AStartup.cb := SizeOf(AStartup);
    AStartup.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    AStartup.wShowWindow := SW_HIDE;
    AStartup.hStdInput := OpenNullDevice;
    if AUseStdOut then AStartup.hStdOutput := AWritePipe else AStartup.hStdOutput := ANullHandle;
    if AUseStdErr then AStartup.hStdError := AWritePipe else AStartup.hStdError := ANullHandle;

    ZeroMemory(@AProcess, SizeOf(AProcess));
    if not CreateProcessW(nil, PWideChar(ACommandLine), nil, nil, True,
                          CREATE_NO_WINDOW, nil, nil, AStartup, AProcess) then Exit;
    try
      CloseHandle(AWritePipe);
      AWritePipe := 0;

      AOutput := '';
      while ReadFile(AReadPipe, ABuffer, BUFFER_SIZE, ABytesRead, nil) and (ABytesRead > 0) do
      begin
        SetLength(AChunk, ABytesRead);
        Move(ABuffer, AChunk[1], ABytesRead);
        AOutput := AOutput + AChunk;
      end;

      WaitForSingleObject(AProcess.hProcess, INFINITE);
      AText := Utf8ToUnicode(AOutput);
      Result := True;
    finally
      if AStartup.hStdInput <> INVALID_HANDLE_VALUE then CloseHandle(AStartup.hStdInput);
      if AWritePipe <> 0 then CloseHandle(AWritePipe);
      CloseHandle(AProcess.hThread);
      CloseHandle(AProcess.hProcess);
    end;
  finally
    if ANullHandle <> INVALID_HANDLE_VALUE then CloseHandle(ANullHandle);
    CloseHandle(AReadPipe);
  end;
end;

procedure SetEditText(ListWin: HWND; const AText: UnicodeString);
begin
  SendMessageW(ListWin, WM_SETTEXT, 0, LPARAM(PWideChar(AText)));
end;

function CreateTextViewer(ParentWin: HWND): HWND;
var
  ARect: TRect;
  ADC: HDC;
  AFontHeight: Integer;
  AFont: HFONT;
begin
  if not GetClientRect(ParentWin, @ARect) then
    ARect := TRect.Create(0, 0, 640, 480);

  Result := CreateWindowW(EDIT_CLASS, nil,
                          WS_CHILD or WS_VISIBLE or WS_VSCROLL or
                          ES_MULTILINE or ES_READONLY or ES_AUTOVSCROLL,
                          ARect.Left, ARect.Top, ARect.Right, ARect.Bottom,
                          ParentWin, 0, GetModuleHandleW(nil), nil);
  if Result = wlxInvalidHandle then Exit;

  ADC := GetDC(Result);
  try
    AFontHeight := -MulDiv(DEFAULT_FONT_SIZE, GetDeviceCaps(ADC, LOGPIXELSY), 72);
  finally
    ReleaseDC(Result, ADC);
  end;

  AFont := CreateFontW(AFontHeight, 0, 0, 0, FW_NORMAL, 0, 0, 0,
                       DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                       DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE,
                       DEFAULT_FONT_NAME);
  if AFont <> 0 then
    SendMessageW(Result, WM_SETFONT, WPARAM(AFont), 1);
end;

function ListLoadW(ParentWin: HWND; FileToLoad: PWideChar; ShowFlags: Integer): HWND; stdcall;
var
  AText: UnicodeString;
begin
  Result := wlxInvalidHandle;
  if not RunCommand(FileToLoad, AText) then Exit;

  Result := CreateTextViewer(ParentWin);
  if Result = wlxInvalidHandle then Exit;

  SetEditText(Result, AText);
end;

function ListLoadNextW(ParentWin, PluginWin: HWND; FileToLoad: PWideChar;
                       ShowFlags: Integer): Integer; stdcall;
var
  AText: UnicodeString;
begin
  Result := LISTPLUGIN_ERROR;
  if PluginWin = wlxInvalidHandle then Exit;
  if not RunCommand(FileToLoad, AText) then Exit;

  SetEditText(PluginWin, AText);
  Result := LISTPLUGIN_OK;
end;

procedure ListCloseWindow(ListWin: HWND); stdcall;
begin
  DestroyWindow(ListWin);
end;

procedure ListGetDetectString(DetectString: PAnsiChar; MaxLen: Integer); stdcall;
begin
  lstrcpynA(DetectString, PAnsiChar(GDetectString), MaxLen);
end;

procedure ListSetDefaultParams(dps: PListDefaultParamStruct); stdcall;
begin
  GDetectString := AnsiString(ReadIniW(INI_DETECT, '*'));
end;

function ListSendCommand(ListWin: HWND; Command, Parameter: Integer): Integer; stdcall;
begin
  case Command of
    lc_copy:
      begin
        SendMessageW(ListWin, WM_COPY, 0, 0);
        Result := LISTPLUGIN_OK;
      end;
    lc_selectall:
      begin
        SendMessageW(ListWin, EM_SETSEL, 0, LPARAM(-1));
        Result := LISTPLUGIN_OK;
      end;
  else
    Result := LISTPLUGIN_ERROR;
  end;
end;

exports
  ListLoadW,
  ListLoadNextW,
  ListCloseWindow,
  ListGetDetectString,
  ListSetDefaultParams,
  ListSendCommand;

end.
