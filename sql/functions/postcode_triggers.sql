-- Trigger functions for location_postcode table.


-- Trigger for updates of location_postcode
--
-- Computes the parent object the postcode most likely refers to.
-- This will be the place that determines the address displayed when
-- searching for this postcode.
CREATE OR REPLACE FUNCTION postcode_update()
  RETURNS TRIGGER
  AS $$
DECLARE
  partition SMALLINT;
  location RECORD;
BEGIN
    IF NEW.indexed_status != 0 OR OLD.indexed_status = 0 THEN
        RETURN NEW;
    END IF;

    NEW.indexed_date = now();

    partition := get_partition(NEW.country_code);

    SELECT * FROM get_postcode_rank(NEW.country_code, NEW.postcode)
      INTO NEW.rank_search, NEW.rank_address;

    NEW.parent_place_id = 0;
    FOR location IN
      SELECT place_id
        FROM getNearFeatures(partition, NEW.geometry, NEW.rank_search, '{}'::int[])
        WHERE NOT isguess ORDER BY rank_address DESC LIMIT 1
    LOOP
        NEW.parent_place_id = location.place_id;
    END LOOP;

    RETURN NEW;
END;
$$
LANGUAGE plpgsql;

