(* *****************************************************************************
  *
  * MyHomeLib
  *
  * Copyright (C) 2008-2010 Aleksey Penkov
  *
  * Created             12.02.2010
  * Description
  * Author(s)           Nick Rymanov (nrymanov@gmail.com)
  *
  * History
  * NickR 15.02.2010    ��� ����������������
  *
  ****************************************************************************** *)

unit unit_Helpers;

interface

uses
  Windows,
  Classes,
  Dialogs,
  Graphics,
  Generics.Collections;

type
  TStringListEx = class(TStringList)
  public
    procedure LoadFromStream(Stream: TStream); override;
  end;

  TIniStringList = class(TStringList)
  public
    constructor Create; overload;
  end;

function GetFileSize(const FileName: string): Integer;

function GetOpenFileName(
  const Title: string;
  const DefaultExt: string;
  const Filter: string;
  out strFileName: string;
  const dialogKey: string = '';
  ExtraOptions: TOpenOptions = []
  ): Boolean;

function GetSaveFileName(
  const Title: string;
  const DefaultExt: string;
  const Filter: string;
  out strFileName: string;
  const dialogKey: string = '';
  ExtraOptions: TOpenOptions = []
  ): Boolean;

type
  TMHLFileName = (
    fnGenreList,
    fnOpenCollection,
    fnSelectReader,
    fnSelectScript,
    fnOpenImportFile,
    fnSaveCollection,
    fnSaveLog,
    fnSaveImportFile,
    fnOpenINPX,
    fnSaveINPX,
    fnOpenUserData,
    fnSaveUserData,
    fnOpenCoverImage
  );

function GetFileName(key: TMHLFileName; out FileName: string): Boolean;

function GetFolderName(Handle: Integer; const Caption: string; var strFolder: string): Boolean;

function CreateImageFromResource(GraphicClass: TGraphicClass; const ResName: string; ResType: PChar = RT_RCDATA): TGraphic;

//
// �������, ��� �� ������ ����� ��� ��������� �������.
// TODO : ������� ��� ������� � ��������� ������
//

type
  TConversion<T> = reference to function(const items: T): string;

  TArrayUtils = class
  public
    class function Join<T>(
      const Values: array of T;
      const itemDelimeter: string;
      const Converter: TConversion<T>
    ): string;

    class function Join2<T>(
      const Values: TEnumerable<T>;
      const itemDelimeter: string;
      const Converter: TConversion<T>
    ): string;
  end;


implementation

uses
  SysUtils,
  Forms,
  unit_Settings,
  ShlObj,
  ActiveX;

// ============================================================================
// TStringListEx
// ============================================================================
procedure TStringListEx.LoadFromStream(Stream: TStream);
const
  UTF8BOM: array [1..3] of Byte = ($EF, $BB, $BF); //the UTF-8 byte order mark (BOM).
var
  FIsUTF8File: Boolean;
  APosition: Int64;
  bomBuffer: array [1..3] of Byte;
begin
  APosition := Stream.Position;
  FIsUTF8File := False;

  if Stream.Read(bomBuffer, SizeOf(bomBuffer)) = SizeOf(bomBuffer) then
  begin
    FIsUTF8File := (bomBuffer[1] = UTF8BOM[1]) and (bomBuffer[2] = UTF8BOM[2]) or (bomBuffer[3] = UTF8BOM[3]);
  end;

  if not FIsUTF8File then
    Stream.Position := APosition;

  inherited;
end;

// ============================================================================
// TIniStringList
// ============================================================================
constructor TIniStringList.Create;
begin
  inherited Create;

  QuoteChar := '"';
  Delimiter := ';';
  StrictDelimiter := True;
end;

// ============================================================================
function GetFileSize(const FileName: string): Integer;
var
  hFile: Integer;
begin
  hFile := SysUtils.FileOpen(FileName, fmOpenRead or fmShareDenyWrite);
  if hFile = -1 then
    RaiseLastOSError;

  Result := Windows.GetFileSize(hFile, nil);
  SysUtils.FileClose(hFile);
end;

// ============================================================================
type
  TStdDialogClass = class of TOpenDialog;

function InternalGetFileName(
  DialogClass: TStdDialogClass;
  const Title: string;
  const DefaultExt: string;
  const Filter: string;
  out strFileName: string;
  ExtraOptions: TOpenOptions;
  const dialogKey: string = ''
  ): Boolean;
var
  dlg: TOpenDialog;
begin
  dlg := DialogClass.Create(nil);
  try
    if Title <> '' then
      dlg.Title := Title;
    dlg.DefaultExt := DefaultExt;
    dlg.Filter := Filter;
    dlg.Options := dlg.Options + ExtraOptions;
    dlg.InitialDir := Settings.InitialDir[dialogKey];

    Result := dlg.Execute;
    if Result then
    begin
      strFileName := dlg.FileName;

      Settings.InitialDir[dialogKey] := ExtractFilePath(strFileName);
    end;
  finally
    dlg.Free;
  end;
end;

function GetOpenFileName(
  const Title: string;
  const DefaultExt: string;
  const Filter: string;
  out strFileName: string;
  const dialogKey: string = '';
  ExtraOptions: TOpenOptions = []
  ): Boolean;
begin
  //
  // TODO -oNickR -cUsability : ������������ TFileOpenDialog ��� Vista-��
  //
  Include(ExtraOptions, ofFileMustExist);
  Include(ExtraOptions, ofNoChangeDir);
  Result := InternalGetFileName(TOpenDialog, Title, DefaultExt, Filter, strFileName, ExtraOptions, dialogKey);
end;

function GetSaveFileName(
  const Title: string;
  const DefaultExt: string;
  const Filter: string;
  out strFileName: string;
  const dialogKey: string = '';
  ExtraOptions: TOpenOptions = []
  ): Boolean;
begin
  //
  // TODO -oNickR -cUsability : ������������ TFileSaveDialog ��� Vista-��
  //
  Include(ExtraOptions, ofOverwritePrompt);
  Include(ExtraOptions, ofNoChangeDir);
  Result := InternalGetFileName(TSaveDialog, Title, DefaultExt, Filter, strFileName, ExtraOptions, dialogKey);
end;

type
  TDialogParams = record
    Title: string;
    Filter: string;
    DefaultExt: string;
    DialogKey: string;
    OpenFile: Boolean;
  end;

resourcestring
  //fnGenreList
  rstrGenreListDlgTitle = '����� ������ ������';
  rstrGenreListDlgFilter = '������ ������ MyHomeLib (*.glst)|*.glst|��� ����|*.*';
  rstrGenreListDlgDefaultExt = 'glst';

  // fnOpenCollection
  rstrOpenCollectionDlgTitle = '������� ���� ���������';
  // fnSaveCollection
  rstrSaveCollectionDlgTitle = '��������� ���� ���������';
  rstrCollectionDlgFilter = '��������� MyHomeLib (*.hlc)|*.hlc|��� ����|*.*';
  rstrCollectionDlgDefaultExt = 'hlc';

  // fnSelectReader
  rstrSelectReaderDlgTitle = '����� ��������� ��� ���������';
  // fnSelectScript
  rstrSelectScriptDlgTitle = '����� �������';
  rstrSelectProgrammDlgFilter = '�������, ��������� (*.exe;*.bat;*.cmd;*.vbs;*.js)|*.exe;*.bat;*.cmd;*.vbs;*.js|��� ����|*.*';
  rstrSelectProgrammDlgDefaultExt = 'exe';

  // fnOpenImportFile
  rstrOpenImportFileDlgTitle = '������� xml';
  // fnSaveImportFile
  rstrSaveImportFileDlgTitle = '��������� xml';
  rstrImportFileDlgFilter = 'xml (*.xml)|*.xml|��� ����|*.*';
  rstrImportFileDlgDefaultExt = 'xml';

  // fnSaveLog
  rstrSaveLogDlgTitle = '��������� ��� ������';
  rstrSaveLogDlgFilter = '���� ��������� (*.log)|*.log|��� ����|*.*';
  rstrSaveLogDlgDefaultExt = 'log';
  //fnOpenINPX
  rstrOpenINPXDlgTitle = '����� ����� �������';
  rstrOpenINPXDlgFilter = '������ ���� MyHomeLib (*.inpx)|*.inpx|��� ����|*.*';
  rstrOpenINPXDlgDefaultExt = 'inpx';

  //fnSaveINPX
  rstrSaveINPXDlgTitle = '����� ����� �������';
  rstrSaveINPXDlgFilter = '������ ���� MyHomeLib (*.inpx)|*.inpx|��� ����|*.*';
  rstrSaveINPXDlgDefaultExt = 'inpx';

  //fnSaveUserData
  rstrOpenUDDlgTitle = '������ ���������������� ������';
  rstrOpenUDDlgFilter = '���������������� ������ MyHomeLib (*.mhlud)|*.mhlud|��� ����|*.*';
  rstrOpenUDDlgDefaultExt = 'mhlud';

  //fnOpenUserData
  rstrSaveUDDlgTitle = '������� ���������������� ������';
  rstrSaveUDDlgFilter = '���������������� ������ MyHomeLib (*.mhlud)|*.mhlud|��� ����|*.*';
  rstrSaveUDDlgDefaultExt = 'mhlud';

  //fnOpenCoverImage
  rstrOpenCIDlgTitle = '�������� ����� �������';
  rstrOpenCIDlgFilter = '����������� (png jpg jpeg)|*.jpeg;*.jpg;*.png';
  rstrOpenCIDlgDefaultExt = 'jpeg';


function GetFileName(key: TMHLFileName; out FileName: string): Boolean;
const
  DlgParams: array[TMHLFileName] of TDialogParams = (
    ( // fnGenreList
      Title:      rstrGenreListDlgTitle;
      Filter:     rstrGenreListDlgFilter;      DefaultExt: rstrGenreListDlgDefaultExt;
      DialogKey:  'SelectGenreList';           OpenFile:   True
    ),
    ( // fnOpenCollection
      Title:      rstrOpenCollectionDlgTitle;
      Filter:     rstrCollectionDlgFilter;     DefaultExt: rstrCollectionDlgDefaultExt;
      DialogKey:  'OpenCollection';            OpenFile:   True
    ),
    ( // fnSelectReader
      Title:      rstrSelectReaderDlgTitle;
      Filter:     rstrSelectProgrammDlgFilter; DefaultExt: rstrSelectProgrammDlgDefaultExt;
      DialogKey:  'SelectReader';              OpenFile:   True
    ),
    ( // fnSelectScript
      Title:      rstrSelectScriptDlgTitle;
      Filter:     rstrSelectProgrammDlgFilter; DefaultExt: rstrSelectProgrammDlgDefaultExt;
      DialogKey:  'SelectScript';              OpenFile:   True
    ),
    ( // fnOpenImportFile
      Title:      rstrOpenImportFileDlgTitle;
      Filter:     rstrImportFileDlgFilter;     DefaultExt: rstrImportFileDlgDefaultExt;
      DialogKey:  'OpenImportFile';            OpenFile:   True
    ),
    ( // fnSaveCollection
      Title:      rstrSaveCollectionDlgTitle;
      Filter:     rstrCollectionDlgFilter;     DefaultExt: rstrCollectionDlgDefaultExt;
      DialogKey:  'SaveCollection';            OpenFile:   False
    ),
    ( // fnSaveLog
      Title:      rstrSaveLogDlgTitle;
      Filter:     rstrSaveLogDlgFilter;        DefaultExt: rstrSaveLogDlgDefaultExt;
      DialogKey:  'SaveLog';                   OpenFile:   False
    ),
    ( // fnSaveImportFile
      Title:      rstrSaveImportFileDlgTitle;
      Filter:     rstrImportFileDlgFilter;     DefaultExt: rstrImportFileDlgDefaultExt;
      DialogKey:  'SaveImportFile';            OpenFile:   False
    ),
    ( // fnLoadINPX
      Title:      rstrOpenINPXDlgTitle;
      Filter:     rstrOpenINPXDlgFilter;     DefaultExt: rstrOpenINPXDlgDefaultExt;
      DialogKey:  'OpenINPXFile';            OpenFile:   True
    ),
    ( // fnSaveINPX
      Title:      rstrSaveINPXDlgTitle;
      Filter:     rstrSaveINPXDlgFilter;     DefaultExt: rstrSaveINPXDlgDefaultExt;
      DialogKey:  'SaveINPXFile';            OpenFile:   False
    ),
    ( // fnOpenUserData
      Title:      rstrOpenUDDlgTitle;
      Filter:     rstrOpenUDDlgFilter;     DefaultExt: rstrOpenUDDlgDefaultExt;
      DialogKey:  'OpenUserData';            OpenFile: True
    ),
    ( // fnSaveUserData
      Title:      rstrSaveUDDlgTitle;
      Filter:     rstrSaveUDDlgFilter;     DefaultExt: rstrSaveUDDlgDefaultExt;
      DialogKey:  'SaveUserData';            OpenFile: False
    ),
    ( // fnOpenCoverImage
      Title:      rstrOpenCiDlgTitle;
      Filter:     rstrOpenCiDlgFilter;     DefaultExt: rstrOpenCIDlgDefaultExt;
      DialogKey:  'OpenCoverImage';        OpenFile: True
    )



    //(Title: ''; Filter: ''; DefaultExt: ''; ExtraOptions: ; DialogKey: ''; GetFileNameFunction:)
  );
begin
  if DlgParams[key].OpenFile then
    Result := GetOpenFileName(
      DlgParams[key].Title, DlgParams[key].DefaultExt, DlgParams[key].Filter, FileName, DlgParams[key].DialogKey, []
      )
  else
    Result := GetSaveFileName(
      DlgParams[key].Title, DlgParams[key].DefaultExt, DlgParams[key].Filter, FileName, DlgParams[key].DialogKey, []
      );
end;

function BrowseCallbackProc(hwnd: HWND; uMsg: UINT; lParam: LPARAM; lpData: LPARAM): Integer; stdcall;
begin
  if (uMsg = BFFM_INITIALIZED) then
    SendMessage(hwnd, BFFM_SETSELECTION, 1, lpData);
  BrowseCallbackProc := 0;
end;

function GetFolderName(Handle: Integer; const Caption: string; var strFolder: string): Boolean;
var
  BrowseInfo: TBrowseInfo;
  lpItemID: PItemIDList;

  DisplayName: array [0 .. MAX_PATH] of Char;
  TempPath : array[0..MAX_PATH] of Char;
begin
  //
  // TODO DONE -oNickR -cUsability : ������������ InitialDir
  //

  Result := False;

  FillChar(BrowseInfo, SizeOf(TBrowseInfo), #0);

  if 0 <> Handle then
    BrowseInfo.hwndOwner := Handle
  else
    BrowseInfo.hwndOwner := Application.Handle;

  BrowseInfo.pszDisplayName := @DisplayName;
  BrowseInfo.lpszTitle := PChar(Caption);
  BrowseInfo.ulFlags := BIF_RETURNONLYFSDIRS or BIF_USENEWUI;
  BrowseInfo.lpfn := @BrowseCallbackProc;
  BrowseInfo.lParam := LPARAM(PChar(strFolder));

  lpItemID := SHBrowseForFolder(BrowseInfo);
  if Assigned(lpItemId) then
  begin
    Result := SHGetPathFromIDList(lpItemID, TempPath);
    if Result then
    begin
      strFolder := StrPas(TempPath);
      //
      // TODO DONE -oNickR -cUsability : ��������� InitialDir
      //
    end;
    CoTaskMemFree(lpItemID);
  end;
end;

function CreateImageFromResource(GraphicClass: TGraphicClass; const ResName: string; ResType: PChar): TGraphic;
var
  s: TResourceStream;
begin
  s := TResourceStream.Create(HInstance, ResName, ResType);
  try
    Result := GraphicClass.Create;
    Result.LoadFromStream(s);
  finally
    s.Free;
  end;
end;

{ TArrayUtils }

class function TArrayUtils.Join<T>(const Values: array of T; const itemDelimeter: string; const Converter: TConversion<T>): string;
var
  i, L, R: Integer;
begin
  if Length(Values) = 0 then
    Exit;

  L := Low(Values);
  R := High(Values);

  Result := Converter(Values[L]);
  Inc(L);

  while L <= R do
  begin
    Result := Result + itemDelimeter + Converter(Values[L]);
    Inc(L);
  end;
end;

class function TArrayUtils.Join2<T>(
  const Values: TEnumerable<T>;
  const itemDelimeter: string;
  const Converter: TConversion<T>
  ): string;
var
  Enum: TEnumerator<T>;
begin
  Enum := Values.GetEnumerator();
  try
    if Enum.MoveNext then
    begin
      Result := Converter(Enum.Current);
      while Enum.MoveNext do
        Result := Result + itemDelimeter + Converter(Enum.Current);
    end;
  finally
    Enum.Free;
  end;
end;

end.



