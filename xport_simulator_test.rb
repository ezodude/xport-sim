require "rubygems"

require "test/unit"
require "rr"

require "net/telnet"
require "serialport"
require "xport_simulator"

class Test::Unit::TestCase
  include RR::Adapters::TestUnit
end

class XportSimulatorTest < Test::Unit::TestCase
  IP_ADDRESS = "0.0.0.0"
  PORT_NO = "9999"
  
  TELNET_WAITTIME = 2.0
  TELNET_PROMPT = /.*/
  TELNET_MODE = false
  TELNET_CONNECTION_ESTABLISHED_STATUS = "Connected to "
  TELNET_CONNECTION_NOT_ESTABLISHED_STATUS = "Random content "
  
  SERIAL_PORT_ID_CONFIG = "/dev/tty.usbserial-A70060tq"
  SERIAL_BAUD_RATE_CONFIG = 9600
  SERIAL_DATA_BITS_CONFIG = 8
  SERIAL_STOP_BITS_CONFIG = 1 # use a stop bit
  SERIAL_PARITY_CONFIG = SerialPort::NONE
  
  CONNECT_SERIAL_MSG = "C#{IP_ADDRESS}/#{PORT_NO}\n"
  
  def setup
    @fake_serial_port = StringIO.new("")
    stub(SerialPort).new(SERIAL_PORT_ID_CONFIG, SERIAL_BAUD_RATE_CONFIG, SERIAL_DATA_BITS_CONFIG, SERIAL_STOP_BITS_CONFIG, SERIAL_PARITY_CONFIG) do
      @fake_serial_port
    end
    
    @fake_telnet_connection = Object.new
    def @fake_telnet_connection.close; end
    
    @testee = XportSimulator.new(SERIAL_PORT_ID_CONFIG, SERIAL_BAUD_RATE_CONFIG)
  end
  
  def test_uses_telnet_to_establish_a_connection_to_the_web_server
    stub(@fake_serial_port).gets { CONNECT_SERIAL_MSG }
    mock(Net::Telnet).new('Host' => IP_ADDRESS, 'Port' => PORT_NO, 'Waittime' => TELNET_WAITTIME, 'Prompt' => TELNET_PROMPT, \
      'Telnetmode' => TELNET_MODE) { @fake_telnet_connection }
    
    @testee.listen(once=true)
  end
  
  def test_is_connected_after_a_successful_connection_to_the_web_server
    stub(@fake_serial_port).gets { CONNECT_SERIAL_MSG }
    stub(Net::Telnet).new('Host' => IP_ADDRESS, 'Port' => PORT_NO, 'Waittime' => TELNET_WAITTIME, 'Prompt' => TELNET_PROMPT, \
      'Telnetmode' => TELNET_MODE).yields(TELNET_CONNECTION_ESTABLISHED_STATUS) { @fake_telnet_connection }
      
    @testee.listen(once=true)
    assert(@testee.connected?)
  end
  
  def test_is_still_disconnected_after_an_unsuccessful_connection_to_the_web_server
    stub(@fake_serial_port).gets { CONNECT_SERIAL_MSG }
    stub(Net::Telnet).new('Host' => IP_ADDRESS, 'Port' => PORT_NO, 'Waittime' => TELNET_WAITTIME, 'Prompt' => TELNET_PROMPT, \
      'Telnetmode' => TELNET_MODE).yields(TELNET_CONNECTION_NOT_ESTABLISHED_STATUS) { @fake_telnet_connection }
    @testee.listen(once=true)
    
    assert(!@testee.connected?)
  end
  
  def test_writes_C_byte_after_successful_connection_attemtp_to_web_server
    stub(@fake_serial_port).gets { CONNECT_SERIAL_MSG }
    stub(Net::Telnet).new('Host' => IP_ADDRESS, 'Port' => PORT_NO, 'Waittime' => TELNET_WAITTIME, 'Prompt' => TELNET_PROMPT, \
      'Telnetmode' => TELNET_MODE).yields(TELNET_CONNECTION_ESTABLISHED_STATUS) { @fake_telnet_connection }
      
    mock(@fake_serial_port).write('C')
    
    @testee.listen(once=true)
  end
  
  def test_writes_D_byte_when_still_disconnected_after_an_unsuccessful_connection_attempt_to_web_server
    stub(@fake_serial_port).gets { CONNECT_SERIAL_MSG }
    stub(Net::Telnet).new('Host' => IP_ADDRESS, 'Port' => PORT_NO, 'Waittime' => TELNET_WAITTIME, 'Prompt' => TELNET_PROMPT, \
      'Telnetmode' => TELNET_MODE).yields(TELNET_CONNECTION_NOT_ESTABLISHED_STATUS) { @fake_telnet_connection }
      
    mock(@fake_serial_port).write('D')
    
    @testee.listen(once=true)
  end
  
  def test_closes_the_serial_port_on_program_termination
    stub(@fake_serial_port).gets { "some message" }
    mock(@fake_serial_port).close
    
    @testee.listen(once=true)
  end
  
  def test_returns_complete_response_for_serially_received_http_request
    expected_http_response = %Q(
      HTTP/1.1 200 OK
      Date: Fri, 14 Apr 2006 21:31:37 GMT
      Server: Apache/2.0.52 (Red Hat)
      Content-Length: 13
      Connection: text/html; charset=UTF-8
      Connection: close
      
      some response
    ).strip
    
    stub(@testee).connected? {true}
    stub(@testee).telnet_connection {@fake_telnet_connection}
    
    stub(@fake_serial_port).gets { "GET /get/request/path HTTP/1.1\n" }
    stub(@fake_telnet_connection).cmd("GET /get/request/path HTTP/1.1\n") { expected_http_response }
    
    mock(@fake_serial_port).write(expected_http_response)
    @testee.listen(once=true) 
  end
  
  def test_disconnects_from_web_server_after_making_an_http_request
    stub(@fake_serial_port).gets { CONNECT_SERIAL_MSG }
    stub(@fake_serial_port).close
    stub(Net::Telnet).new('Host' => IP_ADDRESS, 'Port' => PORT_NO, 'Waittime' => TELNET_WAITTIME, 'Prompt' => TELNET_PROMPT, \
      'Telnetmode' => TELNET_MODE).yields(TELNET_CONNECTION_ESTABLISHED_STATUS) { @fake_telnet_connection }
    
    @testee.listen(once=true)
    
    stub(@fake_serial_port).gets { "GET /get/request/path HTTP/1.1\n" }
    stub(@fake_telnet_connection).cmd("GET /get/request/path HTTP/1.1\n") { "some response" }
    
    mock(@fake_telnet_connection).close
    @testee.listen(once=true)
    assert(!@testee.connected?)
  end
end