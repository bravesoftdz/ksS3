{*******************************************************************************
*                                                                              *
*  ksAwsConst - Amazon Web Service Constants                                   *
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

unit ksAwsConst;

interface

const
  C_EMPTY_HASH        = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
  C_LF                = #10;
  C_AMZ_DATE_FORMAT   = 'yyyymmdd"T"hhnnss"Z"';
  C_SHORT_DATE_FORMAT = 'yyyymmdd';
  C_AMAZON_DOMAIN     = 'amazonaws.com';
  C_HASH_ALGORITHM    = 'AWS4-HMAC-SHA256';
  C_PROTOCOL          = 'https';
  C_S3_RGN_EU_CENTRAL_1   = 'eu-central-1';
  C_S3_RGN_EU_NORTH_1     = 'eu-north-1';
  C_S3_RGN_EU_SOUTH_1     = 'eu-south-1';
  C_S3_RGN_EU_WEST_1      = 'eu-west-1';
  C_S3_RGN_EU_WEST_2      = 'eu-west-2';
  C_S3_RGN_EU_WEST_3      = 'eu-west-3';
  C_S3_RGN_US_EAST_1      = 'us-east-1';
  C_S3_RGN_US_EAST_2      = 'us-east-2';
  C_S3_RGN_US_WEST_1      = 'us-west-1';
  C_S3_RGN_US_WEST_2      = 'us-west-2';


implementation

end.
