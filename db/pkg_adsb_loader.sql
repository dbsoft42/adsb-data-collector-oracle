CREATE OR REPLACE PACKAGE pkg_adsb_loader
AS
    g_orphan_status_update_max_age number(4,0) := 600;

    FUNCTION epoch_to_ts (
                            epoch_secs IN number
                        )
    RETURN TIMESTAMP;

    PROCEDURE load_data (
                            in_json IN clob,
                            out_res OUT varchar2
                        );

    PROCEDURE set_params (
                            in_orphan_status_update_max_age IN number
                        );

    PROCEDURE stage_cleanup(
                                in_max_age IN number,
                                out_res OUT varchar2
                            );
END pkg_adsb_loader;


CREATE OR REPLACE PACKAGE BODY pkg_adsb_loader
AS
    PROCEDURE stage_json (
                            in_json IN clob
                        )
    AS
    -- Creates a new record in the json_stage tabel with the suuplied JSON string
    BEGIN
        DBMS_OUTPUT.PUT_LINE(epoch_to_ts(json_value(in_json, '$.now')));
        INSERT INTO json_stage
        (
            time,
            json_text,
            status
        )
        VALUES
        (
            epoch_to_ts(json_value(in_json, '$.now')),
            in_json,
            'RECEIVED'
        );

        COMMIT;
    END stage_json;

    PROCEDURE load_aircraft (
                                in_ts IN timestamp,
                                io_res IN OUT varchar2
                            )
    AS
    -- Creates new aircraft records and updates last_seen time of existing records
    BEGIN
        -- Insert those aircraft which are not already existing
        INSERT INTO aircraft
        (
            hex,
            first_seen,
            last_seen
        )
        SELECT
            j.hex,
            j.time,
            j.time
        FROM view_json_stage j
        WHERE j.time = in_ts
        AND NOT EXISTS (
                SELECT 1 FROM aircraft a
                WHERE a.hex = j.hex
            );
        io_res := 'New aircraft: ' || SQL%rowcount;
        -- Update last_seen for those thata are already existing
        UPDATE aircraft a
        SET last_seen = in_ts
        WHERE hex IN (
            SELECT hex FROM view_json_stage j
            WHERE j.time = in_ts
        );
        io_res := io_res || ', Updated aircraft: ' || SQL%rowcount;
        -- Commit in calling block
    END load_aircraft;

    PROCEDURE load_flight (
                            in_ts timestamp,
                            io_res IN OUT varchar2
                        )
    AS
    -- Creates new flight records in the flights table and updates last_seen times of existing records
    BEGIN
        -- Insert those flights which are not existing
        INSERT INTO flights
        (
            flight,
            hex,
            first_seen,
            last_seen
        )
        SELECT
            trim(j.flight),
            j.hex,
            j.time,
            j.time
        FROM view_json_stage j
        WHERE j.time = in_ts
            AND trim(j.flight) IS NOT NULL
            AND NOT EXISTS (
                SELECT 1 FROM flights f
                WHERE trim(j.flight) = f.flight
                    AND j.hex = f.hex
            );
        io_res := io_res || ', New flights: ' || SQL%rowcount;
        -- Update last_seen for those flights which are already existing
        UPDATE flights f
        SET last_seen = in_ts
        WHERE (hex, flight) IN (
            SELECT hex, trim(j.flight) FROM view_json_stage j
            WHERE j.time = in_ts
                AND trim(j.flight) IS NOT NULL
        );
        io_res := io_res || ', Updated flights: ' || SQL%rowcount;
        -- Commit in calling block
    END load_flight;

    PROCEDURE load_status (
                            in_ts timestamp,
                            io_res IN OUT varchar2
                        )
    AS
    -- Creates new status entries in the status table and updats older records without a flight ID if a flight ID has since been received
        TYPE t_flights_type is table of flights%rowtype;
        t_flights t_flights_type;
    BEGIN
        -- Insert new status records (if different from existing records)
        INSERT INTO status
        (
            hex,
            time,
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
            nav_modes,
            lat,
            lon,
            nic,
            rc,
            version,
            nic_baro,
            nac_p,
            nac_v,
            sil,
            sil_type,
            gva,
            sda,
            mlat,
            mode_a,
            mode_c,
            rssi
        )
        SELECT
             hex,
            time,
            trim(flight),
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
            trim(nullif(nvl(nav_mode_1, '') || ' ' ||
                    nvl(nav_mode_2, '') || ' ' ||
                    nvl(nav_mode_3, '') || ' ' ||
                    nvl(nav_mode_4, '') || ' ' ||
                    nvl(nav_mode_5, '') || ' ' ||
                    nvl(nav_mode_6, ''), '')) nav_modes,
            lat,
            lon,
            nic,
            rc,
            version,
            nic_baro,
            nac_p,
            nac_v,
            sil,
            sil_type,
            gva,
            sda,
            mlat,
            nvl2(modea, 1, 0) modea,
            nvl2(modec, 1, 0) modec,
            rssi
        FROM view_json_stage j
        WHERE time = in_ts
            AND j.lat IS NOT NULL
            AND (j.alt_baro IS NOT NULL OR j.alt_geom IS NOT NULL)
            AND NOT EXISTS (
                SELECT 1 FROM status s
                WHERE s.hex = j.hex
                    AND s.flight = trim(j.flight)
                    AND j.flight IS NOT NULL
                    AND s.lat = j.lat
                    AND s.lon = j.lon
                    AND (
                          (s.alt_baro = j.alt_baro AND s.alt_baro IS NOT NULL AND j.alt_baro IS NOT NULL)
                          OR
                          (s.alt_geom = j.alt_geom AND s.alt_geom IS NOT NULL AND j.alt_geom IS NOT NULL)
                        )
                    AND s.time >= in_ts - (g_orphan_status_update_max_age/60/60/24)
            ); -- Keeping comparison fields limited to a few major ones
        io_res := io_res || ', New status: ' || SQL%rowcount;
        -- Retroactively update older status records (which don't have the flight ID yet)
        SELECT * BULK COLLECT INTO t_flights FROM flights where last_seen = in_ts;
        FORALL indx in t_flights.first..t_flights.last
            UPDATE status
            SET flight = t_flights(indx).flight
            WHERE flight IS NULL
                AND hex = t_flights(indx).hex
                AND time >= in_ts - (g_orphan_status_update_max_age/60/60/24);
        io_res := io_res || ', Retroactively updated status: ' || SQL%rowcount;
        -- Commit in calling block
    END load_status;

    PROCEDURE load_data (
                            in_json IN clob,
                            out_res OUT varchar2
                        )
    AS
    -- The entry point to the load process - this calls all the other procedures.
    -- The final commit also happens here.
        l_ts timestamp;
    BEGIN
        -- Stage JSON
        stage_json(in_json);
        -- Set status to PROCESSING
        l_ts := epoch_to_ts(json_value(in_json, '$.now'));
        UPDATE json_stage SET status = 'PROCESSING', start_time = CURRENT_TIMESTAMP WHERE time = l_ts;
        COMMIT;
        -- Do the loads
        load_aircraft(l_ts, out_res);
        load_flight(l_ts, out_res);
        load_status(l_ts, out_res);
        -- Set status to DONE
        UPDATE json_stage SET status = 'DONE', end_time = CURRENT_TIMESTAMP WHERE time = l_ts;
        -- Final commit
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            UPDATE json_stage SET status = 'FAILED', end_time = CURRENT_TIMESTAMP WHERE time = l_ts;
            COMMIT;
            out_res := 'Something went wrong.' || CHR(10) 
                || DBMS_UTILITY.FORMAT_ERROR_STACK || CHR(10) || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            raise;
    END load_data;

    FUNCTION epoch_to_ts (
                            epoch_secs IN number
                        )
    RETURN TIMESTAMP
    AS
    -- Simple function to convert UNIX epoch timestamp to Oracle timestamp
    BEGIN
        RETURN FROM_TZ(TIMESTAMP '1970-01-01 00:00:00', '0:00') AT LOCAL + (epoch_secs/60/60/24);
    END epoch_to_ts;

    PROCEDURE set_params (
                            in_orphan_status_update_max_age IN number
                        )
    AS
    BEGIN
        g_orphan_status_update_max_age := in_orphan_status_update_max_age;
    END set_params;

    PROCEDURE stage_cleanup(
                                in_max_age IN number,
                                out_res OUT varchar2
                            )
    AS
    -- Deletes record from json_stage that are older than the supplied number of seconds.
    BEGIN
        DELETE FROM json_stage
        WHERE time < CURRENT_TIMESTAMP - (in_max_age/60/60/24);
        out_res := 'Cleanup: ' || SQL%rowcount || ' records deleted';
        COMMIT;
    END stage_cleanup;

END pkg_adsb_loader;
