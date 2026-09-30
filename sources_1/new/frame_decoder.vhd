library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;

entity frame_decoder is
    port (
        clk : in std_logic;
        reset : in std_logic;
        frame : in std_logic_vector(111 downto 0);
        start : in std_logic; 
        done : out std_logic;
        
        icao : out std_logic_vector(23 downto 0);
        callsign : out string(1 to 8);
        lat, lon : out std_logic_vector(16 downto 0);
        speed : out unsigned(9 downto 0);
        alt : out std_logic_vector(12 downto 0);
        heading : out unsigned(9 downto 0)
    );
end frame_decoder;


architecture rtl of frame_decoder is
    

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
        variable candidate : integer;
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
    signal flag : std_logic := '0';
    
begin
    
    process (clk)
        
        -- variables for speed and heading
        variable subt : std_logic_vector(2 downto 0) := (others => '0');
        variable intent_change : std_logic := '0';
        variable dir_ew : std_logic := '0';
        variable vel_ew : signed(9 downto 0) := (others => '0');
        variable dir_ns : std_logic := '0';
        variable vel_ns : signed(9 downto 0) := (others => '0');
        
    begin
        if rising_edge(clk) then
        
            df <= frame(111 downto 107);
            ca <= frame(106 downto 104);
            icao <= frame(103 downto 80);
            tc <= frame (79 downto 75);
            message <= frame(74 downto 24);
            pi <= frame(23 downto 0);
            done <= '0';

            
            
            if (reset = '1') then
            
                done <= '0';
                callsign <= (others => ' ');
                lat <= (others => '0');
                lon <= (others => '0');
                speed <= (others => '0');
                heading <= (others => '0');
                alt <= (others => '0');
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
                        when others =>
                            -- nothing
                            
                    end case;
                end if;
            end if;
        end if;
    end process;
    
    

end rtl;
