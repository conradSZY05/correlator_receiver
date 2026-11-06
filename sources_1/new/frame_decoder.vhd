library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;

entity frame_decoder is
    generic (
        REF_LAT : integer := 6996709;
        REF_LON : integer := 46902564   -- 47185920 - 283356
    );
    port (
        clk : in std_logic;
        reset : in std_logic;
        frame : in std_logic_vector(111 downto 0);
        start : in std_logic; 
        done : out std_logic;
        
        icao : out std_logic_vector(23 downto 0);
        callsign : out string(1 to 8);
        x : out std_logic_vector(8 downto 0);
        y : out std_logic_vector(7 downto 0);
        lat, lon : inout signed(27 downto 0);
        speed : out unsigned(9 downto 0);
        alt : out unsigned(16 downto 0);
        heading : out unsigned(9 downto 0)
    );
end frame_decoder;


architecture rtl of frame_decoder is

    function NL(lat_v : signed(27 downto 0)) return integer is
        -- Array of 57 thresholds mapping where NL transitions downwards from 59 down to 2
        type cpr_threshold_array is array (59 downto 3) of unsigned(23 downto 0);
        constant CPR_LAT_THRESHOLDS : cpr_threshold_array := (
            59 => to_unsigned(1372386, 24), -- 10.4705° -> NL drops to 58
            58 => to_unsigned(1943558, 24), -- 14.8282° -> NL drops to 57
            57 => to_unsigned(2383710, 24), -- 18.1863° -> NL drops to 56
            56 => to_unsigned(2756365, 24), -- 21.0294° -> NL drops to 55
            55 => to_unsigned(3086096, 24), -- 23.5450° -> NL drops to 54
            54 => to_unsigned(3385474, 24), -- 25.8292° -> NL drops to 53
            53 => to_unsigned(3661921, 24), -- 27.9390° -> NL drops to 52
            52 => to_unsigned(3920556, 24), -- 29.9114° -> NL drops to 51
            51 => to_unsigned(4164417, 24), -- 31.7721° -> NL drops to 50
            50 => to_unsigned(4396041, 24), -- 33.5399° -> NL drops to 49
            49 => to_unsigned(4617524, 24), -- 35.2290° -> NL drops to 48
            48 => to_unsigned(4829930, 24), -- 36.8503° -> NL drops to 47
            47 => to_unsigned(5034731, 24), -- 38.4124° -> NL drops to 46
            46 => to_unsigned(5232733, 24), -- 39.9226° -> NL drops to 45
            45 => to_unsigned(5424606, 24), -- 41.3865° -> NL drops to 44
            44 => to_unsigned(5611099, 24), -- 42.8091° -> NL drops to 43
            43 => to_unsigned(5792688, 24), -- 44.1945° -> NL drops to 42
            42 => to_unsigned(5969850, 24), -- 45.5463° -> NL drops to 41
            41 => to_unsigned(6142999, 24), -- 46.8673° -> NL drops to 40
            40 => to_unsigned(6312470, 24), -- 48.1604° -> NL drops to 39
            39 => to_unsigned(6478696, 24), -- 49.4278° -> NL drops to 38
            38 => to_unsigned(6641680, 24), -- 50.6715° -> NL drops to 37
            37 => to_unsigned(6801831, 24), -- 51.8934° -> NL drops to 36
            36 => to_unsigned(6959218, 24), -- 53.0952° -> NL drops to 35
            35 => to_unsigned(7114115, 24), -- 54.2782° -> NL drops to 34
            34 => to_unsigned(7266679, 24), -- 55.4438° -> NL drops to 33
            33 => to_unsigned(7417316, 24), -- 56.5932° -> NL drops to 32
            32 => to_unsigned(7566135, 24), -- 57.7275° -> NL drops to 31
            31 => to_unsigned(7712952, 24), -- 58.8476° -> NL drops to 30
            30 => to_unsigned(7858309, 24), -- 59.9546° -> NL drops to 29
            29 => to_unsigned(8001802, 24), -- 61.0492° -> NL drops to 28
            28 => to_unsigned(8143719, 24), -- 62.1322° -> NL drops to 27
            27 => to_unsigned(8284213, 24), -- 63.2043° -> NL drops to 26
            26 => to_unsigned(8423180, 24), -- 64.2662° -> NL drops to 25
            25 => to_unsigned(8561081, 24), -- 65.3185° -> NL drops to 24
            24 => to_unsigned(8697920, 24), -- 66.3617° -> NL drops to 23
            23 => to_unsigned(8833634, 24), -- 67.3965° -> NL drops to 22
            22 => to_unsigned(8968131, 24), -- 68.4232° -> NL drops to 21
            21 => to_unsigned(9101614, 24), -- 69.4424° -> NL drops to 20
            20 => to_unsigned(9234241, 24), -- 70.4545° -> NL drops to 19
            19 => to_unsigned(9366050, 24), -- 71.4599° -> NL drops to 18
            18 => to_unsigned(9496924, 24), -- 72.4588° -> NL drops to 17
            17 => to_unsigned(9627014, 24), -- 73.4518° -> NL drops to 16
            16 => to_unsigned(9756306, 24), -- 74.4389° -> NL drops to 15
            15 => to_unsigned(9884873, 24), -- 75.4206° -> NL drops to 14
            14 => to_unsigned(10012753, 24),-- 76.3968° -> NL drops to 13
            13 => to_unsigned(10139987, 24),-- 77.3679° -> NL drops to 12
            12 => to_unsigned(10266405, 24),-- 78.3337° -> NL drops to 11
            11 => to_unsigned(10392131, 24),-- 79.2943° -> NL drops to 10
            10 => to_unsigned(10517235, 24),-- 80.2492° -> NL drops to 9
            9  => to_unsigned(10641416, 24),-- 81.1980° -> NL drops to 8
            8  => to_unsigned(10764834, 24),-- 82.1396° -> NL drops to 7
            7  => to_unsigned(10887167, 24),-- 83.0720° -> NL drops to 6
            6  => to_unsigned(11007746, 24),-- 83.9917° -> NL drops to 5
            5  => to_unsigned(11125672, 24),-- 84.8917° -> NL drops to 4
            4  => to_unsigned(11238933, 24),-- 85.7554° -> NL drops to 3
            3  => to_unsigned(11341144, 24) -- 86.5354° -> NL drops to 2
        );
        variable abs_lat : unsigned(27 downto 0);
    begin

        abs_lat := unsigned(abs(lat_v));
        for i in 59 downto 3 loop
            if abs_lat < CPR_LAT_THRESHOLDS(i) then
                return i;
            end if;
        end loop;

        return 2; 
        
    end function;
    

    function atan2(x : signed; y : signed) return unsigned is
        variable xi, yi, ay, r, ang : integer;
    begin
        xi := to_integer(x);
        yi := to_integer(y);
        if xi = 0 and yi = 0 then
            return to_unsigned(0, 10);
        end if;
    
        ay := abs(yi);
        if xi >= 0 then
            r   := ((xi - ay) * 1000) / (xi + ay);
            ang := (45000 - 45 * r) / 1000;      -- degrees
        else
            r   := ((xi + ay) * 1000) / (ay - xi);
            ang := (135000 - 45 * r) / 1000;
        end if;
    
        if yi < 0 then
            ang := 360 - ang;
        end if;
        return to_unsigned(ang, 10);
    end function;
    

    function sqrt(num : unsigned(20 downto 0)) return unsigned is 
        variable result : integer := 0;
    begin
        for candidate in 0 to 724 loop
            if (candidate * candidate) <= to_integer(num) then
                result := candidate;
            end if;
        end loop;
        return to_unsigned(result, 10);
    end function;
    
    
    function square(num : signed) return unsigned is
        variable result : signed((num'length * 2) - 1 downto 0);
    begin
        result := num * num;
        return unsigned(result);
    end function;
    

    function callsign_encode(val : integer) return character is
        variable result : character;
    begin
        case val is
            when 1 to 26 =>
                return character'val(val + 64); -- A-Z
            when 32 =>
                result := ' ';
            when 48 to 57 =>
                return character'val(val); -- 0-9
            when others =>
                result := '_';
        end case;
        return result;
    end function;

    -- raw data
    signal df : std_logic_vector(4 downto 0);
    signal ca : std_logic_vector(2 downto 0);
    signal tc : std_logic_vector(4 downto 0);
    signal message : std_logic_vector(50 downto 0);
    signal pi : std_logic_vector(23 downto 0);
    
    -- decoded data
    signal start_translator : std_logic := '0';
    signal done_translating : std_logic := '0';

    constant MAP_LAT : integer := 6996808;
    constant MAP_LON : integer := -283339;
    
begin

    process (clk)
        
        -- variables for speed and heading
        variable subt : std_logic_vector(2 downto 0) := (others => '0');
        variable intent_change : std_logic := '0';
        variable dir_ew : std_logic := '0';
        variable vel_ew : signed(9 downto 0) := (others => '0');
        variable dir_ns : std_logic := '0';
        variable vel_ns : signed(9 downto 0) := (others => '0');

        -- variables barometric alt
        variable alt_bits : std_logic_vector(11 downto 0) := (others => '0');
        variable Q_bit : std_logic := '0';
        variable n : unsigned(10 downto 0) := (others => '0');
        variable prod : unsigned(21 downto 0) := (others => '0');
        variable alt_s : signed(16 downto 0) := (others => '0');
        -- variables for lon and lat
        constant fact : integer := 199940; -- 6.1016949152542 * 2^15
        variable parity_flag : std_logic := '0';
        variable j : integer := 0;-- two 34 bit multiplied by 5 bits each
        
        variable cpr_lat, cpr_lon : unsigned(16 downto 0);
        variable prod_lat : unsigned(36 downto 0);  -- 17 bit * 20 bit
        variable prod_lon : unsigned(42 downto 0);  -- 17 bit * 26 bit
        variable d_lat, d_lon : integer := 0;
        variable cprpos_lat, cprpos_lon : integer := 0;
        variable lat_i, lon_i : integer := 0;

        variable m : integer := 0;
        variable mn : integer := 0;
        variable XZlatest : integer := 0;
        variable lon_s : signed(27 downto 0) := (others => '0');
        variable NL_lat : integer := 0;
        
        variable px, py : integer := 0;

    begin
        if rising_edge(clk) then
        
            df <= frame(111 downto 107);
            ca <= frame(106 downto 104);
            icao <= frame(103 downto 80);
            tc <= frame (79 downto 75);
            message <= frame(74 downto 24);
            pi <= frame(23 downto 0);
            done <= '0';
            
            -- defaults: outputs are only non-zero for the one cycle after done
            done     <= '0';
            callsign <= (others => ' ');
            lat <= (others => '0');
            lon <= (others => '0');
            speed    <= (others => '0');
            alt      <= (others => '0');
            heading  <= (others => '0');
            
            start_translator <= '0';     
                   
            if (reset = '1') then
                null; -- already cleared
            elsif (start = '1') then 
           
                if (to_integer(unsigned(frame(111 downto 107))) = 17 or
                    to_integer(unsigned(frame(111 downto 107))) = 18) then 
                    -- dont use df directly here because it updates on the next cycle
                    
                    case to_integer(unsigned(frame(79 downto 75))) is
                
                        when 1 to 4 =>
                        
                            -- callsign is 41 to 88 (not 0 indexed) so take reverse
                            for i in 0 to 7 loop
                                callsign(i + 1) <= callsign_encode(
                                    to_integer(unsigned(
                                        frame(71 - i*6 downto 66 - i*6)
                                    ))
                                );
                            end loop;
                            done <= '1';
                        when 9 to 18 =>
                            
                            -- position
                            alt_bits := frame(71 downto 60);
                            Q_bit := alt_bits(4); -- Q bit determines if the altitude is in 25 or 100 foot increments
                            -- its basically always '1' which means 25 foot increments, maybe i'll implement the 100 foot one in the future

                            if (Q_bit = '1') then -- alt is in 25 foot incrememnts

                                -- so remove Q_bit from alt_bits using a mask
                                n := unsigned(alt_bits(11 downto 5) & alt_bits(3 downto 0));
                            end if; -- else is in 100 foot increments
                            prod := resize(n, 17) * to_unsigned(25, 5);
                            alt_s := signed(prod(16 downto 0)) - to_signed(1000, 17); 
                            alt <= unsigned(alt_s);

                            -- local decode of this single frame against the receiver position
                            parity_flag := frame(58);
                            cpr_lat := unsigned(frame(57 downto 41));
                            cpr_lon := unsigned(frame(40 downto 24));
                            
                            -- latitude: zone size is 6 deg (even) or 360/59 deg (odd), in 2^-17 deg
                            if parity_flag = '0' then
                                d_lat := 786432;
                            else
                                d_lat := 799761;
                            end if;
                            prod_lat   := cpr_lat * to_unsigned(d_lat, 20);
                            cprpos_lat := to_integer(prod_lat(36 downto 17));      -- cpr * D / 2^17
                            j    := (REF_LAT - cprpos_lat + d_lat/2) / d_lat;
                            lat_i      := j * d_lat + cprpos_lat;
                            
                            -- longitude: zone count depends on the decoded latitude
                            NL_lat := NL(to_signed(lat_i, 28));
                            if parity_flag = '0' then
                                mn := NL_lat;
                            else
                                mn := NL_lat - 1;
                            end if;
                            if mn < 1 then mn := 1; end if;
                            
                            d_lon      := 47185920 / mn;                           -- 360 deg * 2^17 / zones
                            prod_lon   := cpr_lon * to_unsigned(d_lon, 26);
                            cprpos_lon := to_integer(prod_lon(42 downto 17));
                            m          := (REF_LON - cprpos_lon + d_lon/2) / d_lon;
                            lon_i      := m * d_lon + cprpos_lon;
                            if lon_i > 23592960 then                               -- > 180 deg
                                lon_i := lon_i - 47185920;
                            end if;
                            
                            lat  <= to_signed(lat_i, 28); -- still keeping lat and lon just in case
                            lon  <= to_signed(lon_i, 28);
                            
                            px := 160 + ((lon_i - MAP_LON) * 19) / 131072;
                            py := 120 - (lat_i - MAP_LAT) / 4096;
                            if px >= 0 and px < 320 and py >= 0 and py < 240 then
                                x <= std_logic_vector(to_unsigned(px, 9));
                                y <= std_logic_vector(to_unsigned(py, 8));
                            else
                                x <= (others => '0');
                                y <= (others => '0');
                            end if;
                            
                            -- once we have lat and lon, send to coordinate translator using a separate done signal
                            start_translator <= '1'; 
                            
                            done <= '1' when done_translating = '1' else '0'; -- only pulse done when we know coordinate transator has finished translating to local x and y pixels
                            
                            
                        when 19 =>
                        
                            -- speed and heading
                            subt := frame(75 downto 73);
                            intent_change := frame(72);
                            dir_ew := frame(66);
                            dir_ns := frame(55);
                            -- convert to knots
                            if (dir_ew = '1') then --invert velocity
                                vel_ew := -signed(frame(65 downto 56));
                            else 
                                vel_ew := signed(frame(65 downto 56));
                            end if;
                            if (dir_ns = '1') then
                                vel_ns := -signed(frame(54 downto 45));
                            else
                                vel_ns := signed(frame(54 downto 45));
                            end if;
                            
                            speed <= sqrt(resize(square(vel_ew) + square(vel_ns), 21)); 
                            heading <= atan2(vel_ns, vel_ew);
                            done <= '1';
                            
                        when others =>
                            -- nothing
                            
                    end case;
                end if;
            end if;
        end if;
    end process;
    
    

end rtl;