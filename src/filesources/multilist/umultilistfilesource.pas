unit uMultiListFileSource;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  uFile,
  uFileSource,
  uFileSourceProperty,
  uFileSourceOperation,
  uFileSourceOperationTypes,
  uFileProperty;

type

  IMultiListFileSource = interface(IFileSource)
    ['{A64C591C-EBC6-4E06-89D2-9965E1A3009A}']

    procedure AddList(var aFileList: TFileTree; aFileSource: IFileSource);

    function GetFileList: TFileTree;
    function GetFileSource: IFileSource;

    property FileList: TFileTree read GetFileList;
    property FileSource: IFileSource read GetFileSource;
  end;

  {en
     File source that generates files from file lists generated by other file sources.

     This virtual file source contains "links" to files from other file sources,
     e.g., paths to files on FileSystem file source, or paths to files within
     certain archive. Therefore properties of virtual file source and operations
     will depend on the underlying file source. It should be possible to store
     links to different file sources within the same virtual file source,
     in which case there has to be a file source associated with each file
     or a group of files, although presentation of such file lists should
     probably be different than that of a single file source.

     Files can be virtual (from virtual file sources).

     Currently can only use a single file source with a single file list.
  }

  { TMultiListFileSource }

  TMultiListFileSource = class(TFileSource, IMultiListFileSource)
  private
    {en
       File list for the file source.
    }
    FFileList: TFileTree;
    {en
       File source from which files in FileList come from.
       Currently only single file source is supported.
    }
    FFileSource: IFileSource;

    procedure FileSourceEventListener(var params: TFileSourceEventParams);

  protected
    function GetFileList: TFileTree;
    function GetFileSource: IFileSource;
    procedure DoReload(const PathsToReload: TPathsArray); override;

  public
    constructor Create; override;
    destructor Destroy; override;

    {en
       Adds a list of files associated with a file source to the storage.
       Only single file source supported now (adding list will overwrite
       previous list).

       @param(aFileList
              List of files. Class takes ownership of the pointer.)
       @param(aFileSource
              The file source from which files in aFileList are from.)
    }
    procedure AddList(var aFileList: TFileTree; aFileSource: IFileSource); virtual;

    function GetSupportedFileProperties: TFilePropertiesTypes; override;
    function GetOperationsTypes: TFileSourceOperationTypes; override;
    function GetProperties: TFileSourceProperties; override;

    function CreateDirectory(const Path: String): Boolean; override;
    function FileSystemEntryExists(const Path: String): Boolean; override;

    function GetRetrievableFileProperties: TFilePropertiesTypes; override;
    procedure RetrieveProperties(AFile: TFile; PropertiesToSet: TFilePropertiesTypes; const AVariantProperties: array of String); override;
    function CanRetrieveProperties(AFile: TFile; PropertiesToSet: TFilePropertiesTypes): Boolean; override;

    function CreateListOperation(TargetPath: String): TFileSourceOperation; override;
    function CreateCopyOutOperation(TargetFileSource: IFileSource;
                                    var SourceFiles: TFiles;
                                    TargetPath: String): TFileSourceOperation; override;
    function CreateMoveOperation(var SourceFiles: TFiles;
                                 TargetPath: String): TFileSourceOperation; override;
    function CreateDeleteOperation(var FilesToDelete: TFiles): TFileSourceOperation; override;
    function CreateWipeOperation(var FilesToWipe: TFiles): TFileSourceOperation; override;
    function CreateExecuteOperation(var ExecutableFile: TFile; BasePath, Verb: String): TFileSourceOperation; override;
    function CreateTestArchiveOperation(var theSourceFiles: TFiles): TFileSourceOperation; override;
    function CreateCalcChecksumOperation(var theFiles: TFiles;
                                         aTargetPath: String;
                                         aTargetMask: String): TFileSourceOperation; override;
    function CreateCalcStatisticsOperation(var theFiles: TFiles): TFileSourceOperation; override;
    function CreateSetFilePropertyOperation(var theTargetFiles: TFiles;
                                            var theNewProperties: TFileProperties): TFileSourceOperation; override;

    property FileList: TFileTree read FFileList;
    property FileSource: IFileSource read FFileSource;
  end;

implementation

uses
  uMultiListListOperation;

constructor TMultiListFileSource.Create;
begin
  FFileList := nil;
  FFileSource := nil;
  inherited Create;
end;

destructor TMultiListFileSource.Destroy;
begin
  if Assigned(FFileSource) then begin
    FFileSource.RemoveEventListener(@FileSourceEventListener);
  end;
  inherited Destroy;
  FreeAndNil(FFileList);
  FFileSource := nil;
end;

procedure TMultiListFileSource.AddList(var aFileList: TFileTree; aFileSource: IFileSource);
begin
  if Assigned(FFileList) then
    FreeAndNil(FFileList);

  FFileList := aFileList;
  aFileList := nil;
  FFileSource := aFileSource;

  FFileSource.AddEventListener(@FileSourceEventListener);
end;

function TMultiListFileSource.GetSupportedFileProperties: TFilePropertiesTypes;
begin
  Result := FFileSource.GetSupportedFileProperties;
end;

function TMultiListFileSource.GetOperationsTypes: TFileSourceOperationTypes;
begin
  // Only fsoList is supported by default.
  // All other operations only if file source supports them.
  // However, this will work only for single file source.
  Result := [fsoList] +
      FFileSource.GetOperationsTypes *
        [fsoCopyOut,
         //fsoMove,
         fsoDelete,
         fsoWipe,
         fsoCalcChecksum,
         fsoCalcStatistics,
         fsoSetFileProperty,
         fsoExecute,
         fsoTestArchive];
end;

function TMultiListFileSource.GetProperties: TFileSourceProperties;
begin
  // Flags depend on the underlying file source.
  Result := FFileSource.GetProperties;
end;

function TMultiListFileSource.CreateDirectory(const Path: String): Boolean;
begin
  Result:= FFileSource.CreateDirectory(Path);
end;

function TMultiListFileSource.FileSystemEntryExists(const Path: String): Boolean;
begin
  Result:= FFileSource.FileSystemEntryExists(Path);
end;

function TMultiListFileSource.GetRetrievableFileProperties: TFilePropertiesTypes;
begin
  Result:= FFileSource.GetRetrievableFileProperties;
end;

procedure TMultiListFileSource.RetrieveProperties(AFile: TFile;
  PropertiesToSet: TFilePropertiesTypes; const AVariantProperties: array of String);
begin
  FFileSource.RetrieveProperties(AFile, PropertiesToSet, AVariantProperties);
end;

function TMultiListFileSource.CanRetrieveProperties(AFile: TFile;
  PropertiesToSet: TFilePropertiesTypes): Boolean;
begin
  Result:= FFileSource.CanRetrieveProperties(AFile, PropertiesToSet);
end;

procedure TMultiListFileSource.FileSourceEventListener(var params: TFileSourceEventParams);
begin
  if params.eventType = TFileSourceEventType.reload then
    Reload(params.paths);
end;

function TMultiListFileSource.GetFileList: TFileTree;
begin
  Result := FFileList;
end;

function TMultiListFileSource.GetFileSource: IFileSource;
begin
  Result := FFileSource;
end;

procedure TMultiListFileSource.DoReload(const PathsToReload: TPathsArray);

  procedure ReloadNode(aNode: TFileTreeNode);
  var
    Index: Integer;
    ASubNode: TFileTreeNode;
  begin
    if Assigned(aNode) then
    begin
      for Index := aNode.SubNodesCount - 1 downto 0 do
      begin
        ASubNode:= aNode.SubNodes[Index];
        if FFileSource.FileSystemEntryExists(ASubNode.TheFile.FullPath) then
          ReloadNode(ASubNode)
        else begin
          aNode.RemoveSubNode(Index);
        end;
      end;
    end;
  end;

begin
  ReloadNode(FileList);
end;

function TMultiListFileSource.CreateListOperation(TargetPath: String): TFileSourceOperation;
begin
  Result := TMultiListListOperation.Create(Self, TargetPath);
end;

function TMultiListFileSource.CreateCopyOutOperation(TargetFileSource: IFileSource;
                                                     var SourceFiles: TFiles;
                                                     TargetPath: String): TFileSourceOperation;
begin
  Result := FFileSource.CreateCopyOutOperation(TargetFileSource, SourceFiles, TargetPath);
end;

function TMultiListFileSource.CreateMoveOperation(var SourceFiles: TFiles;
                                                  TargetPath: String): TFileSourceOperation;
begin
  Result := FFileSource.CreateMoveOperation(SourceFiles, TargetPath);
end;

function TMultiListFileSource.CreateDeleteOperation(var FilesToDelete: TFiles): TFileSourceOperation;
begin
  Result := FFileSource.CreateDeleteOperation(FilesToDelete);
end;

function TMultiListFileSource.CreateWipeOperation(var FilesToWipe: TFiles): TFileSourceOperation;
begin
  Result := FFileSource.CreateWipeOperation(FilesToWipe);
end;

function TMultiListFileSource.CreateExecuteOperation(var ExecutableFile: TFile; BasePath, Verb: String): TFileSourceOperation;
begin
  Result := FFileSource.CreateExecuteOperation(ExecutableFile, ExecutableFile.Path, Verb);
end;

function TMultiListFileSource.CreateTestArchiveOperation(var theSourceFiles: TFiles): TFileSourceOperation;
begin
  Result := FFileSource.CreateTestArchiveOperation(theSourceFiles);
end;

function TMultiListFileSource.CreateCalcChecksumOperation(var theFiles: TFiles;
                                                          aTargetPath: String;
                                                          aTargetMask: String): TFileSourceOperation;
begin
  Result := FFileSource.CreateCalcChecksumOperation(theFiles, aTargetPath, aTargetMask);
end;

function TMultiListFileSource.CreateCalcStatisticsOperation(var theFiles: TFiles): TFileSourceOperation;
begin
  Result := FFileSource.CreateCalcStatisticsOperation(theFiles);
end;

function TMultiListFileSource.CreateSetFilePropertyOperation(var theTargetFiles: TFiles;
                                                             var theNewProperties: TFileProperties): TFileSourceOperation;
begin
  Result := FFileSource.CreateSetFilePropertyOperation(theTargetFiles, theNewProperties);
end;

end.

