(* *****************************************************************************
  *
  * MyHomeLib
  *
  * Copyright (C) 2008-2010 Aleksey Penkov
  *
  * Author(s)           Nick Rymanov (nrymanov@gmail.com)
  * Created             12.02.2010
  * Description
  *
  * $Id$
  *
  * History
  * NickR 15.02.2010    Код переформатирован
  *
  ****************************************************************************** *)

unit unit_Readers;

interface

uses
  Windows,
  Classes,
  SysUtils;

type
  TReaderDesc = class(TCollectionItem)
  strict private
    FExtension: string;
    FPath: string;
    procedure SetExtension(const Value: string);

  protected
    procedure AssignTo(Dest: TPersistent); override;

  public
    property Extension: string read FExtension write SetExtension;
    property Path: string read FPath write FPath;
  end;

  TReaders = class(TCollection)
  strict private
    function GetReader(Index: Integer): TReaderDesc;
    procedure SetReader(Index: Integer; const Value: TReaderDesc);

    function AddReader: TReaderDesc;

  public
    constructor Create;

    procedure Add(const Extension: string; const Path: string);
    function Find(const Extension: string): TReaderDesc;

    procedure RunReader(const FileName: string);

    property Items[Index: Integer]: TReaderDesc read GetReader write SetReader; default;
  end;

implementation

uses
  Forms,
  ShellAPI,
  unit_Errors,
  unit_Globals;

{ TReaderC }

procedure TReaderDesc.AssignTo(Dest: TPersistent);
var
  Other: TReaderDesc;
begin
  if Dest is TReaderDesc then
  begin
    Other := TReaderDesc(Dest);
    Other.Extension := Extension;
    Other.Path := Path;
  end
  else
    inherited AssignTo(Dest);
end;

procedure TReaderDesc.SetExtension(const Value: string);
begin
  FExtension := CleanExtension(Value);
end;

{ TReaders }

constructor TReaders.Create;
begin
  inherited Create(TReaderDesc);
end;

function TReaders.AddReader: TReaderDesc;
begin
  Result := TReaderDesc(inherited Add);
end;

procedure TReaders.Add(const Extension, Path: string);
var
  Reader: TReaderDesc;
begin
  if (CleanExtension(Extension) = '') {or (Path = '')} then
    raise EMHLError.Create(rstrErrorInvalidArgument);

  BeginUpdate;
  try
    Reader := AddReader;
    try
      Reader.Extension := Extension;
      Reader.Path := Path;
    except
      Reader.Free;
      raise;
    end;
  finally
    EndUpdate;
  end;
end;

function TReaders.Find(const Extension: string): TReaderDesc;
var
  i: Integer;
  Ext: string;
begin
  Result := nil;
  Ext := CleanExtension(Extension);

  for i := 0 to Count - 1 do
    if CompareText(Items[i].Extension, Ext) = 0 then
    begin
      Result := Items[i];
      Break;
    end;
end;

function TReaders.GetReader(Index: Integer): TReaderDesc;
begin
  Result := TReaderDesc(inherited Items[Index]);
end;

procedure TReaders.RunReader(const FileName: string);
var
  Ext: string;
  AReader: TReaderDesc;
  AHInst: HINST;
begin
  Ext := ExtractFileExt(FileName);

  AReader := Find(Ext);
  if Assigned(AReader) and (AReader.Path <> '') then
    AHInst := ShellExecute(
      Application.Handle,
      'open',
      PChar(AReader.Path),
      PChar('"' + FileName + '"'),
      nil,
      SW_SHOWNORMAL
      )
  else
    AHInst := ShellExecute(
      Application.Handle,
      nil,
      PChar(FileName),
      nil,
      nil,
      SW_SHOWNORMAL
      );

  if AHInst <= 32 then
    raise Exception.Create(SysErrorMessage(AHInst) + ': ' + AReader.Path);
end;

procedure TReaders.SetReader(Index: Integer; const Value: TReaderDesc);
begin
  inherited Items[Index] := Value;
end;

end.
