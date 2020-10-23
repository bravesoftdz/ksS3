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
  TksS3Acl = (ksS3Private, ksS3PublicRead, ksS3PublicReadWrite, ksS3AuthenticatedRead);

  IksAwsS3Object = interface
    ['{C9390D73-62A6-43F1-AAE1-479693BAAAFC}']
    function GetKey: string;
    function GetStream: TStream;
    function GetSize: integer;
    function GetETag: string;
    function GetLastModified: string;
    procedure SaveToFile(AFilename: string);
    property Key: string read GetKey;
    property Stream: TStream read GetStream;
    property Size: integer read GetSize;
    property ETag: string read GetETag;
    property LastModified: string read GetLastModified;
  end;

  IksAwsS3 = interface
    ['{BD814B29-8F03-425F-BF47-FECBEA49D133}']
    function GetObject(ABucketName, AObjectName: string): IksAwsS3Object;
    function CreateBucket(ABucketName: string; AAcl: TksS3Acl): Boolean;
    function DeleteBucket(ABucketName: string): Boolean;
    procedure GetBuckets(ABuckets: TStrings);
    procedure GetBucket(ABucketName: string; AContents: TStrings);
  end;

  function CreateAwsS3(APublicKey, APrivateKey: string; ARegion: TksAwsRegion): IksAwsS3;

implementation

uses ksAwsConst, SysUtils, System.DateUtils, Net.UrlClient, Net.HttpClient, System.Hash, HttpApp,
  System.NetEncoding, Xml.xmldom, Xml.XMLIntf, Xml.XMLDoc, ksAwsHash, Dialogs;

type
  TksAwsS3Object = class(TInterfacedObject, IksAwsS3Object)
  private
    FKey: string;
    FEtag: string;
    FStream: TStream;
    FLastModified: string;
    function GetETag: string;
    function GetStream: TStream;
    function GetSize: integer;
    function GetKey: string;
    function GetLastModified: string;
  protected
    procedure SaveToFile(AFilename: string);

    property Key: string read GetKey;
    property ETag: string read GetETag;
    property LastModified: string read GetLastModified;
    property Size: integer read GetSize;
    property Stream: TStream read GetStream;


  public
    constructor Create(AKey: string;
                       AETag: string;
                       ALastModified: string;
                       AStream: TStream); virtual;
    destructor Destroy; override;
  end;

  TksAwsS3 = class(TksAwsBaseService, IksAwsS3)
  private
    function GetAclString(AAcl: TksS3Acl): string;
  protected
    function GetServiceName: string; override;
    function GetObject(ABucketName, AObjectName: string): IksAwsS3Object;
    function CreateBucket(ABucketName: string; AAcl: TksS3Acl): Boolean;
    function DeleteBucket(ABucketName: string): Boolean;
    procedure GetBuckets(AStrings: TStrings);
    procedure GetBucket(ABucketName: string; AStrings: TStrings);
  end;

function CreateAwsS3(APublicKey, APrivateKey: string; ARegion: TksAwsRegion): IksAwsS3;
begin
  Result := TksAwsS3.Create(APublicKey, APrivateKey, ARegion);
end;

{ TksAwsS3Object }

constructor TksAwsS3Object.Create(AKey: string;
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
  Result := FKey;
end;

function TksAwsS3Object.GetLastModified: string;
begin
  Result := FLastModified;
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

function TksAwsS3.CreateBucket(ABucketName: string; AAcl: TksS3Acl): Boolean;
var
  AResponse: IHTTPResponse;
  APayload: string;
  AHeaders: TStrings;
begin
  AHeaders := TStringList.Create;
  try
    AHeaders.Values['x-amz-acl'] := GetAclString(AAcl);
    APayload := GetPayload(C_PAYLOAD_CREATE_BUCKET);
    AResponse := ExecuteHttp(C_PUT, ABucketName+'.'+Host, '/', APayload, AHeaders, nil);
    Result := AResponse.ContentAsString = '';
  finally
    AHeaders.Free;
  end;
end;

function TksAwsS3.DeleteBucket(ABucketName: string): Boolean;
var
  AResponse: IHTTPResponse;
begin
  AResponse := ExecuteHttp(C_DELETE, ABucketName+'.'+Host, '/', '', nil, nil);
  Result := AResponse.ContentAsString = '';
end;

function TksAwsS3.GetAclString(AAcl: TksS3Acl): string;
begin
  case AAcl of
    ksS3Private: Result := 'private';
    ksS3PublicRead: Result := 'public-read';
    ksS3PublicReadWrite: Result := 'public-read-write';
    ksS3AuthenticatedRead: Result := 'authenticated-read';
  end;
end;

procedure TksAwsS3.GetBucket(ABucketName: string;
                             AStrings: TStrings);
var
  AResponse: IHTTPResponse;
  AXml: IXMLDocument;
  AContents: IXMLNode;
  ICount: integer;
  AObject: IXMLNode;
begin
  AStrings.Clear;
  AResponse := ExecuteHttp(C_GET, ABucketName+'.'+Host, '/', '', nil, nil);
  AXml := TXMLDocument.Create(nil);
  AXml.LoadFromXML(AResponse.ContentAsString());
  AContents := AXml.ChildNodes['ListBucketResult'];
  for ICount := 0 to AContents.ChildNodes.Count-1 do
  begin
    AObject := AContents.ChildNodes[ICount];
    if AObject.NodeName = 'Contents' then
      AStrings.Add(AObject.ChildValues['Key']);
  end;
end;

procedure TksAwsS3.GetBuckets(AStrings: TStrings);
var
  AResponse: IHTTPResponse;
  AXml: IXMLDocument;
  ABuckets: IXMLNode;
  ABucket: IXMLNode;
  ICount: integer;
begin
  AResponse := ExecuteHttp(C_GET, Host, '', '', nil, nil);
  AXml := TXMLDocument.Create(nil);
  AXml.LoadFromXML(AResponse.ContentAsString);
  ABuckets := AXml.ChildNodes['ListAllMyBucketsResult'];
  ABuckets := ABuckets.ChildNodes['Buckets'];
  for ICount := 0 to ABuckets.ChildNodes.Count-1 do
  begin
    ABucket := ABuckets.ChildNodes[ICount];
    AStrings.Add(ABucket.ChildNodes['Name'].Text);
  end;
end;

function TksAwsS3.GetObject(ABucketName, AObjectName: string): IksAwsS3Object;
var
  AResponse: IHTTPResponse;
  AFilename: string;
  AParams: TStrings;
begin
  AParams := TStringList.Create;
  try
    AResponse := ExecuteHttp(C_GET, ABucketName+'.'+Host, AObjectName, '', nil, AParams);
  finally
    AParams.Free;
  end;
  AFilename := AObjectName;
  while Pos('/', AFilename) > 0 do
    AFilename := Copy(AFilename, Pos('/', AFilename)+1, Length(AFilename));

  Result := TksAwsS3Object.Create(AObjectName,
                                  AResponse.HeaderValue['ETag'],
                                  AResponse.LastModified,
                                  AResponse.ContentStream);
end;

function TksAwsS3.GetServiceName: string;
begin
  Result := C_SERVICE_S3;
end;

end.
