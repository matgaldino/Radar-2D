library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Telemetre_IP_TB is
end entity;

architecture Behavioral of Telemetre_IP_TB is

    --------------------------------------------------------------------
    -- DUT Declaration
    --------------------------------------------------------------------
    component Telemetre_IP is
        Port (
            clk     : in  std_logic;
            Rst_n   : in  std_logic;
            trig    : out std_logic;
            echo    : in  std_logic;
            Dist_cm : out std_logic_vector(9 downto 0)
        );
    end component;

    --------------------------------------------------------------------
    -- Testbench signals
    --------------------------------------------------------------------
    signal clk_tb     : std_logic := '0';
    signal rst_n_tb   : std_logic := '0';
    signal trig_tb    : std_logic;
    signal echo_tb    : std_logic := '0';
    signal dist_tb    : std_logic_vector(9 downto 0);

    --------------------------------------------------------------------
    -- Clock and timing constants
    --------------------------------------------------------------------
    constant CLK_PERIOD : time := 20 ns;    -- 50 MHz

    -- Pulse width conversion (approx):
    -- Distance (cm) -> pulse width (us) = cm * 58
    constant ECHO_150CM : time := 150 * 58 us;   -- 8700 us
    constant ECHO_100CM : time := 100 * 58 us;   -- 5800 us
    constant ECHO_401CM : time := 401 * 58 us;   -- 23258 us
    constant ECHO_400CM   : time := 400 * 58 us;   -- 23200 us

begin

    --------------------------------------------------------------------
    -- Clock generation (50 MHz)
    --------------------------------------------------------------------
    clk_process : process
    begin
        clk_tb <= '0';
        wait for CLK_PERIOD / 2;
        clk_tb <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    --------------------------------------------------------------------
    -- DUT instantiation
    --------------------------------------------------------------------
    UUT : Telemetre_IP
        port map(
            clk     => clk_tb,
            Rst_n   => rst_n_tb,
            trig    => trig_tb,
            echo    => echo_tb,
            Dist_cm => dist_tb
        );

    --------------------------------------------------------------------
    -- Stimulus process
    --------------------------------------------------------------------
    stim_proc : process
    begin

        ----------------------------------------------------------------
        -- Reset
        ----------------------------------------------------------------
        rst_n_tb <= '0';
        wait for 200 ns;
        rst_n_tb <= '1';

        ----------------------------------------------------------------
        -- Wait for TRIG to start toggling
        ----------------------------------------------------------------
        wait for 3 ms;

        ----------------------------------------------------------------
        -- FIRST MEASUREMENT: 150 cm
        ----------------------------------------------------------------
        report "Simulating 150 cm echo...";
        echo_tb <= '1';
        wait for ECHO_150CM;
        echo_tb <= '0';

        -- Allow time for measurement and hold-off (~60 ms)
        wait for 80 ms;

        ----------------------------------------------------------------
        -- SECOND MEASUREMENT: 100 cm
        ----------------------------------------------------------------
        report "Simulating 100 cm echo...";
        echo_tb <= '1';
        wait for ECHO_100CM;
        echo_tb <= '0';

        wait for 80 ms;

        ----------------------------------------------------------------
        -- THIRD MEASUREMENT: 401 cm (near max)
        ----------------------------------------------------------------
        report "Simulating 401 cm echo...";
        echo_tb <= '1';
        wait for ECHO_401CM;
        echo_tb <= '0';

        wait for 80 ms;

        ----------------------------------------------------------------
        -- FOURTH MEASUREMENT: 400 cm (max)
        ----------------------------------------------------------------
        report "Simulating 400 cm echo...";
        echo_tb <= '1';
        wait for ECHO_400CM;
        echo_tb <= '0';

        wait for 40 ms;

        ----------------------------------------------------------------
        -- End simulation
        ----------------------------------------------------------------
        report "Simulation finished.";
        wait;

    end process;

end architecture Behavioral;
