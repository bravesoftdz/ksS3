{*******************************************************************************
*                                                                              *
*  ksAwsSes - Amazon S3 Interface for Delphi                                   *
*                                                                              *
*  https://github.com/gmurt/ksStripe                                           *
*                                                                              *
*  Copyright 2020 Graham Murt                                                  *
*                                                                              *
*  email: graham@kernow-software.co.uk                                         *
*                                                                              *
*  Licensed under the Apache License, Version 2.0 (the "License");             *
*  you may not use this file except in compliance with the License.            *
*  You may obtain a copy of the License at                                     *
*                                                                              *
*    http://www.apache.org/licenses/LICENSE-2.0                                *
*                                                                              *
*  Unless required by applicable law or agreed to in writing, software         *
*  distributed under the License is distributed on an "AS IS" BASIS,           *
*  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.    *
*  See the License for the specific language governing permissions and         *
*  limitations under the License.                                              *
*                                                                              *
*******************************************************************************}

unit ksAwsS3;

interface

uses Classes, ksAwsBase;

type
  IksAwsS3Object = interface
    ['{C9390D73-62A6-43F1-AAE1-479693BAAAFC}']
    function GetKey: string;
    function GetObjectName: string;
    function GetStream: TStream;
    function GetSize: integer;
    function GetETag: string;
    function GetLastModified: string;
    procedure SaveToFile(AFilename: string);
    property Key: string read GetKey;
    property ObjectName: string read GetObjectName;
    property Stream: TStream read GetStream;
    property Size: integer read GetSize;
    property ETag: string read GetETag;
    property LastModified: string read GetLastModified;
  end;

  IksAwsS3 = interface
    ['{BD814B29-8F03-425F-BF47-FECBEA49D133}']
    function GetObject(ABucketName, AObjectName: string): IksAwsS3Object;
    procedure GetBuckets(ABuckets: TStrings);
    procedure GetBucket(ABucketName: string; AContents: TStrings);
    procedure CreateBucket(ABucketName: string);
  end;

  function CreateAwsS3(APublicKey, APrivateKey: string; ARegion: TksS3Region): IksAwsS3;

implementation

uses ksAwsConst, SysUtils, System.DateUtils, Net.UrlClient, Net.HttpClient, System.Hash, HttpApp,
  System.NetEncoding, Xml.xmldom, Xml.XMLIntf, Xml.XMLDoc, ksAwsHash;

type
  TksAwsS3Object = class(TInterfacedObject, IksAwsS3Object)
  private
    FKey: string;
    FObjectName: string;
    FEtag: string;
    FStream: TStream;
    FLastModified: string;
    function GetETag: string;
    function GetStream: TStream;
    function GetSize: integer;
    function GetKey: string;
    function GetObjectName: string;
    function GetLastModified: string;
  protected
    procedure SaveToFile(AFilename: string);

    property Key: string read GetKey;
    property ObjectName: string read GetObjectName;
    property ETag: string read GetETag;
    property LastModified: string read GetLastModified;
    property Size: integer read GetSize;
    property Stream: TStream read GetStream;


  public
    constructor Create(AKey: string;
                       AObjectName: string;
                       AETag: string;
                       ALastModified: string;
                       AStream: TStream); virtual;
    destructor Destroy; override;
  end;

  TksAwsS3 = class(TksAwsBaseService, IksAwsS3)
  private
    function PerformGetRequest(ABucket, AObj: string; const AStream: TStream = nil) : IHttpResponse;
    function PerformPutRequest(ABucket, AObj: string; const AStream: TStream = nil) : IHttpResponse;
  protected
    function GetHost(AParams: TStrings): string; override;
    function GetServiceName: string; override;
    function GetObject(ABucketName, AObjectName: string): IksAwsS3Object;
    procedure GetBuckets(AStrings: TStrings);
    procedure GetBucket(ABucketName: string; AStrings: TStrings);
    procedure CreateBucket(ABucketName: string);
  end;


function CreateAwsS3(APublicKey, APrivateKey: string; ARegion: TksS3Region): IksAwsS3;
begin
  Result := TksAwsS3.Create(APublicKey, APrivateKey, ARegion);
end;

{ TksAwsS3Object }

constructor TksAwsS3Object.Create(AKey: string;
                                  AObjectName: string;
                                  AETag: string;
                                  ALastModified: string;
                                  AStream: TStream);
begin
  inherited Create;
  FStream := TMemoryStream.Create;
  FStream.CopyFrom(AStream, AStream.Size);
  FStream.Position := 0;
  FEtag := AETag;
  FKey := AKey;
  FObjectName := AObjectName;
  FLastModified := ALastModified;
end;

destructor TksAwsS3Object.Destroy;
begin
  FStream.Free;
  inherited;
end;

function TksAwsS3Object.GetETag: string;
begin
  Result := FEtag;
end;

function TksAwsS3Object.GetKey: string;
begin
  Result := FLastModified;
end;

function TksAwsS3Object.GetLastModified: string;
begin
  Result := FLastModified;
end;

function TksAwsS3Object.GetObjectName: string;
begin
  Result := FObjectName;
end;

function TksAwsS3Object.GetSize: integer;
begin
  Result := FStream.Size;
end;

function TksAwsS3Object.GetStream: TStream;
begin
  Result := FStream;
end;

procedure TksAwsS3Object.SaveToFile(AFilename: string);
begin
  (FStream as TMemoryStream).SaveToFile(AFilename);
end;

{ TksAwsS3 }


procedure TksAwsS3.CreateBucket(ABucketName: string);
begin
  PerformPutRequest(ABucketName, '');
end;

procedure TksAwsS3.GetBucket(ABucketName: string; AStrings: TStrings);
var
  AResponse: string;
  AXml: IXMLDocument;
  AContents: IXMLNode;
  AObject: IXMLNode;
  ICount: integer;
begin
  AStrings.BeginUpdate;
  try
    AStrings.Clear;
    AResponse := PerformGetRequest(ABucketName, '').ContentAsString;
    AXml := TXMLDocument.Create(nil);
    AXml.LoadFromXML(AResponse);
    AContents := AXml.ChildNodes['ListBucketResult'];
    for ICount := 0 to AContents.ChildNodes.Count-1 do
    begin
      AObject := AContents.ChildNodes[ICount];
      if AObject.NodeName = 'Contents' then
        AStrings.Add(AObject.ChildValues['Key']);
    end;
  finally
    AStrings.EndUpdate;
  end;
end;

procedure TksAwsS3.GetBuckets(AStrings: TStrings);
var
  AResponse: string;
  AXml: IXMLDocument;
  ABuckets: IXMLNode;
  ABucket: IXMLNode;
  ICount: integer;
begin
  AStrings.BeginUpdate;
  try
    AStrings.Clear;
    AResponse := PerformGetRequest('', '').ContentAsString;
    AXml := TXMLDocument.Create(nil);
    AXml.LoadFromXML(AResponse);
    ABuckets := AXml.ChildNodes['ListAllMyBucketsResult'];
    ABuckets := ABuckets.ChildNodes['Buckets'];
    for ICount := 0 to ABuckets.ChildNodes.Count-1 do
    begin
      ABucket := ABuckets.ChildNodes[ICount];
      AStrings.Add(ABucket.ChildNodes['Name'].Text);
    end;
  finally

    AStrings.EndUpdate;
  end;
end;

function TksAwsS3.GetHost(AParams: TStrings): string;
begin
  Result := inherited GetHost(AParams);
  if AParams.Values['bucket'] <> '' then
    Result := AParams.Values['bucket']+'.'+Result;
end;

function TksAwsS3.GetObject(ABucketName, AObjectName: string): IksAwsS3Object;
var
  AResponse: IHTTPResponse;
  AStream: TStream;
  AFilename: string;
begin
  AStream := TMemoryStream.Create;
  try
    AResponse := PerformGetRequest(ABucketName, AObjectName, AStream);
    AFilename := AObjectName;
    while Pos('/', AFilename) > 0 do
      AFilename := Copy(AFilename, Pos('/', AFilename)+1, Length(AFilename));
    Result := TksAwsS3Object.Create(AFilename,
                                    AObjectName,
                                    AResponse.HeaderValue['ETag'],
                                    AResponse.LastModified,
                                    AStream);
  finally
    AStream.Free;
  end;
end;

function TksAwsS3.GetServiceName: string;
begin
  Result := 's3';
end;

function TksAwsS3.PerformGetRequest(ABucket, AObj: string; const AStream: TStream = nil): IHttpResponse;
var
  AUrl: string;
  AParams: TStrings;
begin
  AUrl := GenerateUrl(ABucket, AObj);
  AParams := TStringList.Create;
  try
    AParams.Values['bucket'] := ABucket;
    AParams.Values['object'] := AObj;
    SetHttpHeaders(AParams);
  finally
    AParams.Free;
  end;
  Result := FHttp.Get(AURL, AStream);
  if AStream <> nil then
    AStream.Position := 0;
end;

function TksAwsS3.PerformPutRequest(ABucket, AObj: string; const AStream: TStream): IHttpResponse;
var
  AUrl: string;
  AParams: TStrings;
  AContent: TStringStream;

begin
  AUrl := GenerateUrl(ABucket, AObj);
  AParams := TStringList.Create;
  try
    AParams.Values['bucket'] := ABucket;
    SetHttpHeaders(AParams);
  finally
    AParams.Free;
  end;

  AContent := TStringStream.Create('<CreateBucketConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">' +
                '<LocationConstraint>' + RegionStr + '</LocationConstraint>' +
                '</CreateBucketConfiguration>');
  AContent.position := 0;
  FHttp.CustomHeaders['x-amz-content-sha256'] :=  GetHashSHA256Hex(AContent.DataString);
  FHttp.CustomHeaders['Content-Length'] := IntToStr(AContent.Size);
  FHttp.CustomHeaders['Content-Type'] := 'application/x-www-form-urlencoded; charset=utf-8';


  Result := FHttp.Put(AURL, AContent);
  if AStream <> nil then
    AStream.Position := 0;
end;

end.
