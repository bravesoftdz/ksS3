unit ksAwsHash;

interface

  function GetHashSHA256Hex( HashString: string): string;
  function CalculateHMACSHA256(const AValue: string; const AKey: TArray<Byte>): TArray<Byte>;
  function CalculateHMACSHA256Hex(const AValue: string; const AKey: TArray<Byte>): string;


implementation

uses System.Hash;

function GetHashSHA256Hex( HashString: string): string;
begin
  Result := THash.DigestAsString(THashSHA2.GetHashBytes(HashString));
end;

function CalculateHMACSHA256(const AValue: string; const AKey: TArray<Byte>): TArray<Byte>;
begin
  Result := THashSHA2.GetHMACAsBytes(AValue, AKey);
end;

function CalculateHMACSHA256Hex(const AValue: string; const AKey: TArray<Byte>): string;
begin
  Result := THash.DigestAsString(CalculateHMACSHA256(AValue, AKey));
end;

end.
