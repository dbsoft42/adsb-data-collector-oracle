CREATE TABLE "JSON_STAGE"
 (	"TIME" TIMESTAMP (6) NOT NULL ENABLE,
"JSON_TEXT" CLOB NOT NULL ENABLE,
"STATUS" VARCHAR2(20 BYTE) NOT NULL ENABLE,
"START_TIME" TIMESTAMP (6),
"END_TIME" TIMESTAMP (6),
 CONSTRAINT "CHECK_JSON" CHECK ("JSON_TEXT" IS JSON (LAX)) ENABLE,
 CONSTRAINT "JSON_STAGE_PK" PRIMARY KEY ("TIME")
USING INDEX ENABLE
 )
LOB ("JSON_TEXT") STORE AS SECUREFILE;


CREATE TABLE "AIRCRAFT"
 (	"HEX" CHAR(6 BYTE) NOT NULL ENABLE,
"FIRST_SEEN" TIMESTAMP (6) NOT NULL ENABLE,
"LAST_SEEN" TIMESTAMP (6) NOT NULL ENABLE,
 CONSTRAINT "AIRCRAFT_PK" PRIMARY KEY ("HEX")
USING INDEX ENABLE
 );

 CREATE TABLE "FLIGHTS"
  (	"FLIGHT" VARCHAR2(15 BYTE) NOT NULL ENABLE,
	"HEX" CHAR(6 BYTE) NOT NULL ENABLE,
	"FIRST_SEEN" TIMESTAMP (6) NOT NULL ENABLE,
	"LAST_SEEN" TIMESTAMP (6) NOT NULL ENABLE,
	 CONSTRAINT "FLIGHTS_PK" PRIMARY KEY ("FLIGHT", "HEX")
 USING INDEX ENABLE,
	 CONSTRAINT "FLIGHTS_FK1" FOREIGN KEY ("HEX")
	  REFERENCES "AIRCRAFT" ("HEX") ENABLE
  );


CREATE TABLE "STATUS"
 (
  "TIME" TIMESTAMP (6) NOT NULL ENABLE,
  "HEX" CHAR(6 BYTE) NOT NULL ENABLE,
  "FLIGHT" VARCHAR2(15 BYTE),
  "ALT_BARO" NUMBER(6,0),
  "ALT_GEOM" NUMBER(6,0),
  "GS" NUMBER(5,1),
  "IAS" NUMBER(4,0),
  "TAS" NUMBER(4,0),
  "MACH" NUMBER(4,3),
  "TRACK" NUMBER(4,1),
  "TRACK_RATE" NUMBER(5,2),
  "ROLL" NUMBER(4,1),
  "MAG_HEADING" NUMBER(4,1),
  "TRUE_HEADING" NUMBER(4,1),
  "BARO_RATE" NUMBER(5,0),
  "GEOM_RATE" NUMBER(5,0),
  "SQUAWK" NUMBER(4,0),
  "CATEGORY" CHAR(2 BYTE),
  "NAV_QNH" NUMBER(5,1),
  "NAV_ALTITUDE_MCP" NUMBER(6,0),
  "NAV_ALTITUDE_FMS" NUMBER(6,0),
  "NAV_HEADING" NUMBER(4,1),
  "NAV_MODES" VARCHAR2(100 BYTE),
  "LAT" NUMBER(9,3),
  "LON" NUMBER(9,3),
  "NIC" NUMBER(2,0),
  "RC" NUMBER(3,0),
  "VERSION" NUMBER(2,0),
  "NIC_BARO" NUMBER(2,0),
  "NAC_P" NUMBER(2,0),
  "NAC_V" NUMBER(2,0),
  "SIL" NUMBER(1,0),
  "SIL_TYPE" VARCHAR2(10 BYTE),
  "GVA" NUMBER(1,0),
  "SDA" NUMBER(1,0),
  "MLAT" NUMBER(3,0),
  "MODE_A" NUMBER(1,0),
  "MODE_C" NUMBER(1,0),
  "RSSI" NUMBER(4,1),
CONSTRAINT "STATUS_PK" PRIMARY KEY ("HEX", "TIME")
USING INDEX ENABLE,
 CONSTRAINT "STATUS_FK1" FOREIGN KEY ("HEX")
  REFERENCES "AIRCRAFT" ("HEX") ENABLE
 );

 CREATE OR REPLACE VIEW view_json_stage AS
   SELECT m.time, m.status, j."NOW",j."HEX",j."FLIGHT",j."ALT_BARO",j."ALT_GEOM",j."GS",j."IAS",j."TAS",j."MACH",j."TRACK",j."TRACK_RATE",j."ROLL",j."MAG_HEADING",j."TRUE_HEADING",j."BARO_RATE",j."GEOM_RATE",j."SQUAWK",j."CATEGORY",j."NAV_QNH",j."NAV_ALTITUDE_MCP",j."NAV_ALTITUDE_FMS",j."NAV_HEADING",j."MODEA",j."MODEC",j."LAT",j."LON",j."NIC",j."RC",j."VERSION",j."NAC_P",j."NAC_V",j."NIC_BARO",j."SIL",j."SIL_TYPE",j."GVA",j."SDA",j."RSSI",j."MLAT",j."NAV_MODE_1",j."NAV_MODE_2",j."NAV_MODE_3",j."NAV_MODE_4",j."NAV_MODE_5",j."NAV_MODE_6"
     FROM json_stage m, json_table(
     m.json_text, '$' COLUMNS(
         now,
         NESTED aircraft[*]
             COLUMNS (
                 hex,
                 flight,
                 alt_baro,
                 alt_geom,
                 gs,
                 ias,
                 tas,
                 mach,
                 track,
 				track_rate,
                 roll,
                 mag_heading,
 				true_heading,
                 baro_rate,
                 geom_rate,
                 squawk,
                 category,
                 nav_qnh,
                 nav_altitude_mcp,
                 nav_altitude_fms,
                 nav_heading,
                 Nested nav_modes
                     COLUMNS (
                         nav_mode_1 PATH '$[0]',
                         nav_mode_2 PATH '$[1]',
                         nav_mode_3 PATH '$[2]',
                         nav_mode_4 Path '$[3]',
                         nav_mode_5 PATH '$[4]',
                         nav_mode_6 PATH '$[5]'
                     ),
                 modea,
                 modec,
                 lat,
                 lon,
                 nic,
                 rc,
                 version,
                 nac_p,
                 nac_v,
                 nic_baro,
                 sil,
                 sil_type,
                 gva,
                 sda,
                 rssi,
                 mlat PATH '$.mlat.size()'
             )
         )
     ) j;