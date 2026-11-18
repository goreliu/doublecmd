{
   Double commander
   -------------------------------------------------------------------------
   PeekHead wlx plugin - shows the first 4096 bytes of a file as UTF-8 text.
}

library PeekHead;

{$mode objfpc}{$H+}

uses
  SysUtils, Windows, Messages, WlxPlugin;

const
  PEEK_SIZE = 4096;
  EDIT_CLASS = 'Edit';
  DEFAULT_FONT_NAME: PWideChar = 'Segoe UI';
  DEFAULT_FONT_SIZE = 10;

type
  TTextBuffer = array[0..PEEK_SIZE * 2 - 1] of Byte;

function ReadHead(const FileToLoad: PWideChar; out AText: UnicodeString): Boolean;
var
  AFile: THandle;
  ABuffer: TTextBuffer;
  BytesRead: DWORD;
  I, OutLen: Integer;
  WideLen: Integer;
  NeedsConvert: Boolean;
begin
  Result := False;
  AText := '';

  AFile := CreateFileW(FileToLoad, GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE,
                       nil, OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN, 0);
  if AFile = INVALID_HANDLE_VALUE then Exit;
  try
    if not ReadFile(AFile, ABuffer, PEEK_SIZE, BytesRead, nil) then Exit;
  finally
    CloseHandle(AFile);
  end;

  if BytesRead = 0 then Exit;

  { Windows edit controls expect CRLF line breaks. Convert bare LF to CRLF
    before decoding so LF-only text files are displayed with line breaks.
    Use a temporary buffer when at least one bare LF is present. }
  NeedsConvert := False;
  for I := 0 to Integer(BytesRead) - 1 do
  begin
    if (ABuffer[I] = 10) and                  // LF
       ((I = 0) or (ABuffer[I - 1] <> 13)) then // not already CRLF
    begin
      NeedsConvert := True;
      Break;
    end;
  end;

  OutLen := Integer(BytesRead);
  if NeedsConvert then
  begin
    { Expand from the end so reading ABuffer[I - 1] still sees the original
      byte, not a byte already shifted by an earlier conversion. }
    I := Integer(BytesRead) - 1;
    OutLen := Integer(BytesRead) - 1;
    while I >= 0 do
    begin
      if (ABuffer[I] = 10) and
         ((I = 0) or (ABuffer[I - 1] <> 13)) then
      begin
        ABuffer[OutLen] := 10;
        Dec(OutLen);
        ABuffer[OutLen] := 13;
        Inc(OutLen);
      end
      else
        ABuffer[OutLen] := ABuffer[I];
      Dec(OutLen);
      Dec(I);
    end;
    OutLen := Integer(BytesRead) * 2 - OutLen - 1;
  end;

  WideLen := MultiByteToWideChar(CP_UTF8, 0, @ABuffer, OutLen, nil, 0);
  if WideLen <= 0 then Exit;

  SetLength(AText, WideLen);
  if MultiByteToWideChar(CP_UTF8, 0, @ABuffer, OutLen,
                         PWideChar(AText), WideLen) <= 0 then
  begin
    AText := '';
    Exit;
  end;

  Result := True;
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
  if not ReadHead(FileToLoad, AText) then Exit;

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
  if not ReadHead(FileToLoad, AText) then Exit;

  SetEditText(PluginWin, AText);
  Result := LISTPLUGIN_OK;
end;

procedure ListCloseWindow(ListWin: HWND); stdcall;
begin
  DestroyWindow(ListWin);
end;

procedure ListGetDetectString(DetectString: PAnsiChar; MaxLen: Integer); stdcall;
begin
  lstrcpynA(DetectString, '*', MaxLen);
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
  ListSendCommand;

end.
