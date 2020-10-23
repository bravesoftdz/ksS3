{*******************************************************************************
*                                                                              *
*  ksAwsConst - Amazon Web Service Base Classes                                *
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

unit ksAwsBase;

interface

uses Net.HttpClient, Net.UrlClient, Classes;

type
  TksAwsRegion = (awsEuCentral1, awsEuNorth1, awsEuSouth1, awsEuWest1, awsEuWest2, awsEuWest3, awsUsEast1, awsUsEast2, awsUsWest1, awsUsWest2);

  TksAwsBaseService = class(TInterfacedObject)
  private
    FPublicKey: string;
    FPrivateKey: string;
    FRegion: TksAwsRegion;
    function GetRegionStr: string;
    procedure DoValidateCert(const Sender: TObject; const ARequest: TURLRequest; const Certificate: TCertificate; var Accepted: Boolean);
    procedure GetHeaders(AHost, APayload: string; AHeaders: TStrings; var ADelimited: string);
    function GetUrl(AHost, APath: string; AParams: TStrings): string;
  protected
    function GetHost: string; virtual;
    function GetPayload(AStr: string): string;
    function GenerateUrl(ASubDomain, APath: string): string;
    function GetServiceName: string; virtual; abstract;
    function GenerateCanonicalRequest(AVerb, AHost, URI, APayload: string; AHeaders, AQueryValues: TStrings): string; overload;
    function GenerateSignature(ANow: TDateTime; AStrToSign: string): string;
    function ExecuteHttp(AVerb, AHost, APath, APayload: string; AExtraHeaders, AParams: TStrings): IHttpResponse;
  public
    constructor Create(APublicKey, APrivateKey: string; ARegion: TksAwsRegion);
    property PublicKey: string read FPublicKey;
    property PrivateKey: string read FPrivateKey;
    property Region: TksAwsRegion read FRegion;
    property RegionStr: string read GetRegionStr;
    property ServiceName: string read GetServiceName;
    property Host: string read GetHost;
  end;

implementation

uses ksAwsConst, ksAwsHash, SysUtils, System.Hash, System.NetEncoding, DateUtils;

{ TksAwsBaseService }

constructor TksAwsBaseService.Create(APublicKey, APrivateKey: string; ARegion: TksAwsRegion);
begin
  inherited Create;
  FPublicKey := APublicKey;
  FPrivateKey := APrivateKey;
  FRegion := ARegion;
end;

function TksAwsBaseService.GetUrl(AHost, APath: string; AParams: TStrings): string;
var
  ICount: integer;
begin
  Result := C_PROTOCOL+'://'+AHost+APath;
  if AParams <> nil then
  begin
    for ICount := 0 to AParams.Count-1 do
    begin
      if ICount = 0 then
        Result := Result + '?'
      else
        Result := Result + '&';
      Result := Result + AParams.Names[ICount]+'='+AParams.ValueFromIndex[ICount];
    end;
  end;
end;

procedure TksAwsBaseService.DoValidateCert(const Sender: TObject;
  const ARequest: TURLRequest; const Certificate: TCertificate;
  var Accepted: Boolean);
begin
  Accepted := True;
end;

function TksAwsBaseService.GenerateUrl(ASubDomain, APath: string): string;
begin
  Result := C_PROTOCOL+'://';
  if ASubDomain <> '' then Result := Result + TNetEncoding.URL.Encode(ASubDomain)+'.';
  Result := Result + ServiceName+'.'+RegionStr+'.'+C_AMAZON_DOMAIN+'/';
  if APath <> '' then
    Result := Result + TNetEncoding.URL.Encode(APath, [Ord('#')], []);
end;

function TksAwsBaseService.GenerateSignature(ANow: TDateTime; AStrToSign: string): string;
var
  ADateKey, ARegionKey, AServiceKey, ASigningKey: TArray<Byte>;
begin
  ADateKey := CalculateHMACSHA256(FormatDateTime(C_SHORT_DATE_FORMAT, ANow), TEncoding.UTF8.GetBytes('AWS4' + PrivateKey));
  ARegionKey := CalculateHMACSHA256(RegionStr, ADateKey);
  AServiceKey := CalculateHMACSHA256(ServiceName, ARegionKey);
  ASigningKey := CalculateHMACSHA256('aws4_request', AServiceKey);
  Result := CalculateHMACSHA256Hex(AStrToSign, ASigningKey);
end;

function TksAwsBaseService.GenerateCanonicalRequest(AVerb, AHost, URI, APayload: string; AHeaders, AQueryValues: TStrings): string;
var
  ICount:
  integer;
  AHash: string;
begin
  AHash := GetHashSHA256Hex(APayload);
  Result := TNetEncoding.URL.Encode(AVerb) +C_LF;
  Result := Result + TNetEncoding.URL.Encode(URI, [Ord('#')], []) +C_LF;
  if AQueryValues <> nil then
  begin
    (AQueryValues as TStringList).Sort;
    for ICount := 0 to AQueryValues.Count-1 do
    begin
      Result := Result + TNetEncoding.URL.Encode(AQueryValues.Names[ICount])+'='+TNetEncoding.URL.Encode(AQueryValues.ValueFromIndex[ICount]);
      if ICount < AQueryValues.Count-1 then Result := Result + '&';
    end;
  end;
  Result := Result + C_LF;;
  for ICount := 0 to AHeaders.Count-1 do
    Result := Result + AHeaders.Names[ICount]+':'+AHeaders.ValueFromIndex[ICount]+C_LF;
  Result := Result + C_LF;
  for ICount := 0 to AHeaders.Count-1 do
  begin
    Result := Result + AHeaders.Names[ICount];
    if ICount < AHeaders.Count-1 then
      Result := Result + ';';
  end;
  Result := Result + C_LF;
  Result := Result +GetHashSHA256Hex(APayload);
end;

procedure TksAwsBaseService.GetHeaders(AHost, APayload: string; AHeaders: TStrings; var ADelimited: string);
var
  ICount: integer;
begin
  ADelimited := '';
  AHeaders.Values['host'] := Trim(TNetEncoding.URL.Encode(AHost));
  AHeaders.Values['x-amz-content-sha256'] := GetHashSHA256Hex(APayload); // apayload
  AHeaders.Values['x-amz-date'] := FormatDateTime(C_AMZ_DATE_FORMAT, TTimeZone.Local.ToUniversalTime(Now), TFormatSettings.Create('en-US'));
  (AHeaders as TStringList).Sort;
  for ICount := 0 to AHeaders.Count-1 do
  begin
    ADelimited := ADelimited+AHeaders.Names[ICount];
    if ICount < AHeaders.Count-1 then
      ADelimited := ADelimited + ';';
  end;
end;

function TksAwsBaseService.GetHost: string;
begin
  Result := Format('%s.%s.%s', [ServiceName, RegionStr, C_AMAZON_DOMAIN]);
end;

function TksAwsBaseService.GetPayload(AStr: string): string;
begin
  Result := AStr;
  Result := StringReplace(AStr, '%REGION%', GetRegionStr, [rfReplaceAll]);
end;

function TksAwsBaseService.GetRegionStr: string;
begin
  case FRegion of
    awsEuCentral1: Result := C_RGN_EU_CENTRAL_1;
    awsEuNorth1  : Result := C_RGN_EU_NORTH_1;
    awsEuSouth1  : Result := C_RGN_EU_SOUTH_1;
    awsEuWest1   : Result := C_RGN_EU_WEST_1;
    awsEuWest2   : Result := C_RGN_EU_WEST_2;
    awsEuWest3   : Result := C_RGN_EU_WEST_3;
    awsUsEast1   : Result := C_RGN_US_EAST_1;
    awsUsEast2   : Result := C_RGN_US_EAST_2;
    awsUsWest1   : Result := C_RGN_US_WEST_1;
    awsUsWest2   : Result := C_RGN_US_WEST_2;
  end;
end;

function TksAwsBaseService.ExecuteHttp(AVerb, AHost, APath, APayload: string; AExtraHeaders, AParams: TStrings): IHttpResponse;
var
  AHttp: THTTPClient;
  ICount: integer;
  AHeaders: TStrings;
  ACanonical: string;
  AStringToSign: string;
  ASignature: string;
  AAmzDate: string;
  AAuthHeader: string;
  ANow: TDateTime;
  AShortDate: string;
  AHash: string;
  AUrl: string;
  ADelimitedHeaders: string;
  AStream: TStringStream;
begin
  AHttp := THTTPClient.Create;
  AHeaders := TStringList.Create;
  try
    AHttp.OnValidateServerCertificate := DoValidateCert;
    ANow := Now;
    if Pos('/', APath) <> 1 then
      APath := '/'+APath;
    AHash := GetHashSHA256Hex(APayload);
    if AExtraHeaders <> nil then
      AHeaders.AddStrings(AExtraHeaders);
    GetHeaders(AHost, APayload, AHeaders, ADelimitedHeaders);
    AAmzDate := FormatDateTime(C_AMZ_DATE_FORMAT, TTimeZone.Local.ToUniversalTime(ANow), TFormatSettings.Create('en-US'));
    AShortDate := FormatDateTime(C_SHORT_DATE_FORMAT, TTimeZone.Local.ToUniversalTime(ANow), TFormatSettings.Create('en-US'));
    ACanonical := GenerateCanonicalRequest(AVerb, AHost, APath, APayload,AHeaders, AParams);
    AStringToSign := C_HASH_ALGORITHM +C_LF +
                     AAmzDate +C_LF+
                     FormatDateTime(C_SHORT_DATE_FORMAT, ANow) +'/'+ RegionStr +'/'+ ServiceName +'/aws4_request' +C_LF+
                     GetHashSHA256Hex(ACanonical);
    ASignature := GenerateSignature(ANow, AStringToSign);
    AAuthHeader := C_HASH_ALGORITHM+' Credential='+PublicKey+'/'+
                   FormatDateTime(C_SHORT_DATE_FORMAT, ANow)+'/'+
                   RegionStr+'/'+
                   ServiceName+'/'+
                   'aws4_request,SignedHeaders='+ADelimitedHeaders+',Signature='+ASignature;
    for ICount := 0 to AHeaders.Count-1 do
      AHttp.CustomHeaders[AHeaders.Names[ICount]] := AHeaders.ValueFromIndex[ICount];
    AHttp.CustomHeaders['Authorization'] := AAuthHeader;
    AUrl := GetUrl(AHost, APath, AParams);
    AStream := TStringStream.Create(APayload);
    try
      if AVerb = C_GET then Result := AHttp.Get(AUrl);
      if AVerb = C_PUT then Result := AHttp.Put(AUrl, AStream);
      if AVerb = C_DELETE then Result := AHttp.Delete(AUrl);
    finally
      AStream.Free;
    end;
  finally
    AHeaders.Free;
    AHttp.Free;
  end;
end;

end.
