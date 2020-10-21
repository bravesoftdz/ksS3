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
  TksS3Region = (s3EuCentral1, s3EuNorth1, s3EuSouth1, s3EuWest1, s3EuWest2, s3EuWest3, s3UsEast1, s3UsEast2, s3UsWest1, s3UsWest2);

  TksAwsBaseService = class(TInterfacedObject)
  private
    FPublicKey: string;
    FPrivateKey: string;
    FRegion: TksS3Region;
    function GetRegionStr: string;
    procedure DoValidateCert(const Sender: TObject; const ARequest: TURLRequest; const Certificate: TCertificate; var Accepted: Boolean);
  protected
    FHttp: THTTPClient;
    function GetHost(AParams: TStrings): string; virtual;
    function GenerateUrl(ASubDomain, APath: string): string;
    function GetStringToSign(ARequestTime: TDateTime; AParams: TStrings): string;
    function GetServiceName: string; virtual; abstract;
    function CalculateHMACSHA256(const AValue: string; const AKey: TArray<Byte>): TArray<Byte>;
    function CalculateHMACSHA256Hex(const AValue: string; const AKey: TArray<Byte>): string;
    function GenerateCanonicalRequest(AHost, ADate, APath: string): string;
    function GetHashSHA256Hex(HashString: string): string;
    function GenerateSignature(ARequestTime: TDateTime; AParams: TStrings): string;
    function GetAuthorizationHeaer(ARequestTime: TDateTime; AParams: TStrings): string;
    procedure SetHttpHeaders(ARequestTime: TDateTime; AParams: TStrings);
  public
    constructor Create(APublicKey, APrivateKey: string; ARegion: TksS3Region);
    destructor Destroy; override;
    property PublicKey: string read FPublicKey;
    property PrivateKey: string read FPrivateKey;
    property Region: TksS3Region read FRegion;
    property RegionStr: string read GetRegionStr;
    property ServiceName: string read GetServiceName;
    //property Host: string read GetHost;
  end;

implementation

uses ksAwsConst, SysUtils, System.Hash, System.NetEncoding, DateUtils;

{ TksAwsBaseService }

constructor TksAwsBaseService.Create(APublicKey, APrivateKey: string;
  ARegion: TksS3Region);
begin
  inherited Create;
  FHttp := THTTPClient.Create;
  FPublicKey := APublicKey;
  FPrivateKey := APrivateKey;
  FRegion := ARegion;
  FHttp.OnValidateServerCertificate := DoValidateCert;
end;

destructor TksAwsBaseService.Destroy;
begin
  FHttp.Free;
  inherited;
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

function TksAwsBaseService.GetHashSHA256Hex( HashString: string): string;
begin
  Result := THash.DigestAsString(THashSHA2.GetHashBytes(HashString));
end;

function TksAwsBaseService.CalculateHMACSHA256(const AValue: string; const AKey: TArray<Byte>): TArray<Byte>;
begin
  Result := THashSHA2.GetHMACAsBytes(AValue, AKey);
end;

function TksAwsBaseService.CalculateHMACSHA256Hex(const AValue: string; const AKey: TArray<Byte>): string;
begin
  Result := lowercase(THash.DigestAsString(CalculateHMACSHA256(AValue, AKey)));
end;

function TksAwsBaseService.GenerateSignature(ARequestTime: TDateTime; AParams: TStrings): string;
var
  ADateKey, ARegionKey, AServiceKey, ASigningKey: TArray<Byte>;
  AStrToSign: string;
begin
  AStrToSign := GetStringToSign(ARequestTime, AParams);
  ADateKey := CalculateHMACSHA256(FormatDateTime(C_SHORT_DATE_FORMAT, ARequestTime), TEncoding.UTF8.GetBytes('AWS4' + PrivateKey));
  ARegionKey := CalculateHMACSHA256(RegionStr, ADateKey);
  AServiceKey := CalculateHMACSHA256(ServiceName, ARegionKey);
  ASigningKey := CalculateHMACSHA256('aws4_request', AServiceKey);
  Result := CalculateHMACSHA256Hex(AStrToSign, ASigningKey);
end;


function TksAwsBaseService.GetAuthorizationHeaer(ARequestTime: TDateTime; AParams: TStrings): string;
var
  AShortDate: string;
begin
  AShortDate := FormatDateTime(C_SHORT_DATE_FORMAT, ARequestTime);
  Result := C_HASH_ALGORITHM+' Credential='+PublicKey+'/'+AShortDate+'/'+RegionStr+'/'+ServiceName+'/aws4_request,SignedHeaders=host;x-amz-content-sha256;x-amz-date,Signature='+GenerateSignature(ARequestTime, AParams);
end;


function TksAwsBaseService.GenerateCanonicalRequest(AHost, ADate, APath: string): string;
begin
  Result := TNetEncoding.URL.Encode('GET') +#10;
  Result := Result + '/' + TNetEncoding.URL.Encode(APath, [Ord('#')], []) +#10+#10;
  Result := Result + 'host:' + Trim(TNetEncoding.URL.Encode(AHost)) +#10+
                     'x-amz-content-sha256:' + C_EMPTY_HASH +#10+
                     'x-amz-date:' + Trim(ADate) +#10;
  Result := Result + #10+'host;x-amz-content-sha256;x-amz-date' +#10;
  Result := Result + C_EMPTY_HASH;
end;

function TksAwsBaseService.GetHost(AParams: TStrings): string;
begin
  Result := Format('%s.%s.%s', [ServiceName, RegionStr, C_AMAZON_DOMAIN]);
end;

function TksAwsBaseService.GetRegionStr: string;
begin
  case FRegion of
    s3EuCentral1: Result := C_S3_RGN_EU_CENTRAL_1;
    s3EuNorth1  : Result := C_S3_RGN_EU_NORTH_1;
    s3EuSouth1  : Result := C_S3_RGN_EU_SOUTH_1;
    s3EuWest1   : Result := C_S3_RGN_EU_WEST_1;
    s3EuWest2   : Result := C_S3_RGN_EU_WEST_2;
    s3EuWest3   : Result := C_S3_RGN_EU_WEST_3;
    s3UsEast1   : Result := C_S3_RGN_US_EAST_1;
    s3UsEast2   : Result := C_S3_RGN_US_EAST_2;
    s3UsWest1   : Result := C_S3_RGN_US_WEST_1;
    s3UsWest2   : Result := C_S3_RGN_US_WEST_2;
  end;
end;


function TksAwsBaseService.GetStringToSign(ARequestTime: TDateTime; AParams: TStrings): string;
var
  AAmzDate: string;
  ACanonicalRequest: string;
begin
  AAmzDate := FormatDateTime(C_AMZ_DATE_FORMAT, TTimeZone.Local.ToUniversalTime(ARequestTime), TFormatSettings.Create('en-US'));
  ACanonicalRequest := GenerateCanonicalRequest(GetHost(AParams), AAmzDate, AParams.Values['object']);
  Result := C_HASH_ALGORITHM +C_LF +
            AAmzDate +C_LF+
            FormatDateTime(C_SHORT_DATE_FORMAT, ARequestTime) +'/'+ RegionStr +'/'+ ServiceName +'/aws4_request' +C_LF+
            GetHashSHA256Hex(ACanonicalRequest);

end;

procedure TksAwsBaseService.SetHttpHeaders(ARequestTime: TDateTime;
  AParams: TStrings);
var
  AAuthHeader: string;
begin
  AAuthHeader := GetAuthorizationHeaer(ARequestTime, AParams);
  FHttp.CustomHeaders['Authorization'] := AAuthHeader;
  FHttp.CustomHeaders['x-amz-content-sha256'] := C_EMPTY_HASH;
  FHttp.CustomHeaders['x-amz-date'] := FormatDateTime(C_AMZ_DATE_FORMAT, TTimeZone.Local.ToUniversalTime(ARequestTime), TFormatSettings.Create('en-US'));;
end;

end.
