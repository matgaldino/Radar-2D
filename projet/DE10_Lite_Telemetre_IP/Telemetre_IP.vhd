library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Telemetre_IP is
    Port (
        clk     : in  std_logic;                     
        Rst_n   : in  std_logic;                     
        trig    : out std_logic;                     
        echo    : in  std_logic;                     
        Dist_cm : out std_logic_vector(9 downto 0)   
    );
end Telemetre_IP;


architecture Behavioral of Telemetre_IP is

    --------------------------------------------------------------------
    -- State machine encoding
    --------------------------------------------------------------------
    type state_type is (
        IDLE,
        TRIGGER_HIGH,
        TRIGGER_LOW,
        WAIT_ECHO_HIGH,
        MEASURE_ECHO,
        HOLD_OFF
    );

    signal state, next_state : state_type;

    --------------------------------------------------------------------
    -- Time counters
    --------------------------------------------------------------------
    signal us_counter     : unsigned(31 downto 0) := (others => '0');
    signal echo_counter   : unsigned(31 downto 0) := (others => '0');
    signal dist_cm_int    : unsigned(9 downto 0)  := (others => '0');

    --------------------------------------------------------------------
    -- Trigger register
    --------------------------------------------------------------------
    signal trig_reg : std_logic := '0';

    --------------------------------------------------------------------
    -- 1 µs tick generator
    --------------------------------------------------------------------
    signal clk_div  : unsigned(5 downto 0) := (others => '0');
    signal tick_1us : std_logic := '0';

    --------------------------------------------------------------------
    -- Synchronization of echo
    --------------------------------------------------------------------
    signal echo_s1, echo_s2 : std_logic := '0';
    signal rising_echo      : std_logic;
    signal falling_echo     : std_logic;

begin

    trig    <= trig_reg;
    Dist_cm <= std_logic_vector(dist_cm_int);

    --------------------------------------------------------------------
    -- Synchronize echo to avoid metastability
    --------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            echo_s1 <= echo;
            echo_s2 <= echo_s1;
        end if;
    end process;

    rising_echo  <= '1' when (echo_s2 = '0' and echo_s1 = '1') else '0';
    falling_echo <= '1' when (echo_s2 = '1' and echo_s1 = '0') else '0';


    --------------------------------------------------------------------
    -- Generate 1 µs tick
    --------------------------------------------------------------------
    process(clk, Rst_n)
    begin
        if Rst_n = '0' then
            clk_div  <= (others => '0');
            tick_1us <= '0';
        elsif rising_edge(clk) then
            if clk_div = 49 then
                clk_div  <= (others => '0');
                tick_1us <= '1';
            else
                clk_div  <= clk_div + 1;
                tick_1us <= '0';
            end if;
        end if;
    end process;


    --------------------------------------------------------------------
    -- SEQUENTIAL FSM PROCESS
    --------------------------------------------------------------------
    process(clk, Rst_n)
    begin
        if Rst_n = '0' then
            state        <= IDLE;
            us_counter   <= (others => '0');
            echo_counter <= (others => '0');

        elsif rising_edge(clk) then
            state <= next_state;

            -- Restart counters at beginning of cycle
            if state = IDLE then
                us_counter   <= (others => '0');
                echo_counter <= (others => '0');
            end if;

            -- Increment based on tick
            if tick_1us = '1' then
                case state is
                    when TRIGGER_HIGH  
                        | TRIGGER_LOW 
                        | WAIT_ECHO_HIGH
                        | HOLD_OFF =>
                        us_counter <= us_counter + 1;
                    when MEASURE_ECHO =>
                        null; -- echo_counter handled in 50 MHz domain
                    when others =>
                        null;
                end case;
            end if;

            ----------------------------------------------------------------
            -- Echo counter must increment in **real-time** (50 MHz)
            ----------------------------------------------------------------
            if state = MEASURE_ECHO then
                if echo_s2 = '1' then
                    echo_counter <= echo_counter + 1;
                end if;
            end if;

        end if;
    end process;


    --------------------------------------------------------------------
    -- NEXT STATE LOGIC
    --------------------------------------------------------------------
    process(state, us_counter, echo_s2, rising_echo, falling_echo)
    begin
        next_state <= state;
        trig_reg   <= '0';

        case state is

            when IDLE =>
                next_state <= TRIGGER_HIGH;

            when TRIGGER_HIGH =>
                trig_reg <= '1';
                if us_counter >= 10 then
                    next_state <= TRIGGER_LOW;
                end if;

            when TRIGGER_LOW =>
                if us_counter >= 100 then
                    next_state <= WAIT_ECHO_HIGH;
                end if;

            when WAIT_ECHO_HIGH =>
                if rising_echo = '1' then
                    next_state <= MEASURE_ECHO;
                elsif us_counter >= 40000 then
                    next_state <= HOLD_OFF;
                end if;

            when MEASURE_ECHO =>
                if falling_echo = '1' then
                    next_state <= HOLD_OFF;
                end if;

            when HOLD_OFF =>
                if us_counter >= 60000 then
                    next_state <= IDLE;
                end if;

        end case;
    end process;


    --------------------------------------------------------------------
    -- Distance conversion (executed only after MEASURE_ECHO)
    --------------------------------------------------------------------
    process(state, echo_counter)
        variable temp : integer;
    begin
        if state = HOLD_OFF then
            temp := to_integer(echo_counter) / 2900; -- 2900 cycles per cm
            if temp < 0 then temp := 0; end if;
            if temp > 1023 then temp := 1023; end if;
            dist_cm_int <= to_unsigned(temp, 10);
        end if;
    end process;

end Behavioral;
