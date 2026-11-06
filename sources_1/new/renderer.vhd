library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity renderer is
    generic (
        TABLE_SIZE : integer := 64;
        ADDRESSES  : integer := 76800;  -- 320 x 240
        CENTRE     : integer := 38560   -- receiver position marker
    );
    port (
        clk   : in std_logic;
        reset : in std_logic;

        front_sel : in std_logic;       -- raw from the VGA controller (25 MHz domain)

        callsign_r : in string(1 to 8);
        x_r : in std_logic_vector(8 downto 0);
        y_r : in std_logic_vector(7 downto 0);
        lat_r, lon_r : in signed(27 downto 0);
        alt_r : in unsigned(16 downto 0);
        speed_r : in unsigned(9 downto 0);
        heading_r : in unsigned(9 downto 0);

        rd_idx   : out unsigned(5 downto 0);
        rd_valid : in std_logic;

        wr_en_a : out std_logic;
        wr_en_b : out std_logic;
        wr_data : out std_logic_vector(0 downto 0);
        wr_addr : out std_logic_vector(16 downto 0)
    );
end renderer;

architecture rtl of renderer is
    type t_state is (IDLE, CLEAR_BUFFER, FETCH_ENTRY, WAIT_TABLE, WRITE_ENTRY, NEXT_ENTRY);
    signal state : t_state := IDLE;

    signal sync1, sync2, sync_prev : std_logic := '0';
    signal frame_start : std_logic;
    signal back_sel : std_logic := '0';   -- buffer being drawn: '0' = A, '1' = B
    signal wr_en_r  : std_logic := '0';
begin

    frame_start <= sync2 xor sync_prev;   -- one-cycle pulse when front_sel toggles

    -- '0' means A is written and B is displayed (same convention as top)
    wr_en_a <= wr_en_r when back_sel = '0' else '0';
    wr_en_b <= wr_en_r when back_sel = '1' else '0';

    process (clk)
        variable clear_cnt : integer range 0 to ADDRESSES - 1 := 0;
        variable table_idx : integer range 0 to TABLE_SIZE - 1 := 0;
        variable row : unsigned(16 downto 0);
    begin
        if rising_edge(clk) then
            -- synchroniser runs every cycle
            sync1     <= front_sel;
            sync2     <= sync1;
            sync_prev <= sync2;

            wr_en_r <= '0';               -- default: only write when a state says so

            if reset = '1' then
                state     <= IDLE;
                rd_idx    <= (others => '0');
                wr_data   <= "0";
                wr_addr   <= (others => '0');
                clear_cnt := 0;
                table_idx := 0;
            else
                case state is

                    when IDLE =>
                        if frame_start = '1' then
                            back_sel  <= sync2;       -- draw into the buffer that just became hidden
                            clear_cnt := 0;
                            state     <= CLEAR_BUFFER;
                        end if;

                    when CLEAR_BUFFER =>
                        wr_en_r <= '1';
                        wr_addr <= std_logic_vector(to_unsigned(clear_cnt, 17));
                        if clear_cnt = CENTRE then
                            wr_data <= "1";           -- keep the centre marker
                        else
                            wr_data <= "0";
                        end if;
                        if clear_cnt = ADDRESSES - 1 then
                            table_idx := 0;
                            state     <= FETCH_ENTRY;
                        else
                            clear_cnt := clear_cnt + 1;
                        end if;

                    when FETCH_ENTRY =>
                        rd_idx <= to_unsigned(table_idx, 6);
                        state  <= WAIT_TABLE;

                    when WAIT_TABLE =>
                        state <= WRITE_ENTRY;         -- table registers its output this cycle

                    when WRITE_ENTRY =>
                        -- skip empty slots and entries with no position yet (x = y = 0)
                        if rd_valid = '1' and (x_r /= "000000000" or y_r /= "00000000") then
                            row     := resize(unsigned(y_r), 17);
                            wr_addr <= std_logic_vector(shift_left(row, 8) + shift_left(row, 6)
                                                        + resize(unsigned(x_r), 17));   -- y*320 + x
                            wr_data <= "1";
                            wr_en_r <= '1';
                        end if;
                        state <= NEXT_ENTRY;

                    when NEXT_ENTRY =>
                        if table_idx = TABLE_SIZE - 1 then
                            state <= IDLE;
                        else
                            table_idx := table_idx + 1;
                            state     <= FETCH_ENTRY;
                        end if;

                end case;
            end if;
        end if;
    end process;

end rtl;