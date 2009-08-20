require "rubygems"
require "serialport"
require "net/telnet"

class XportSimulator
  SERIAL_DATA_BITS = 8
  SERIAL_STOP_BITS = 1 # use a stop bit
  SERIAL_PARITY = SerialPort::NONE
  
  TELNET_WAITTIME = 2.0
  TELNET_PROMPT = /.*/
  TELNET_MODE = false
  
  def initialize(serial_port_id, baud_rate=9600)
    @serial_port = SerialPort.new(serial_port_id, baud_rate, SERIAL_DATA_BITS, SERIAL_STOP_BITS, SERIAL_PARITY)
    @telnet_connection = nil
    @connected = false
  end
  
  def listen(once=false)
    begin
      begin
        if raw_value = @serial_port.gets
          raw_value = raw_value.strip
          puts "Read raw value: [#{raw_value}]"
          
          case raw_value
            when /^C\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,5}$/ : 
              @telnet_connection, @connected = telnet_connect(raw_value)
              connected? ? @serial_port.write('C') : @serial_port.write('D')
            
            when /^(GET|POST|PUT|DELETE)\s*.*$/ : 
              if connected?
                @serial_port.write(telnet_connection.cmd("#{raw_value}\n")) 
                telnet_connection.close
                @connected = false
              end
          end
        end
      end while(!once)
    ensure
      @serial_port.close
    end
  end
  
  def telnet_connection
    @telnet_connection
  end
  
  def connected?
    @connected
  end
  
private

  def telnet_connect(connect_command)
    connection_parts = connect_command.split("/")
    ip_address, port_no = connection_parts[0].gsub("C", ""), connection_parts[1]
    
    connected_result = false
    connection_result = \
      Net::Telnet.new('Host' => ip_address, 'Port' => port_no, 'Waittime' => TELNET_WAITTIME, 'Prompt' => TELNET_PROMPT, \
                        'Telnetmode' => TELNET_MODE) { |status| connected_result = true if status =~ /Connected/ }
    [connection_result, connected_result]
  end
end

SERIAL_PORT_ID = "/dev/tty.usbserial-A7007cvp"
BAUD_RATE = 9600 # bits per sec

XportSimulator.new(SERIAL_PORT_ID, BAUD_RATE).listen