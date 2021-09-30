require 'optparse'


#----------------------------
# MAIN
#----------------------------

options = {}

optparse = OptionParser.new do |opt|

    opt.on('-m', '--max_frame=MANDATORY', 'max frame for instructions') { |o| options[:max_frame] = o }
    opt.on('-i', '--include_rate=MANDATORY', 'include a frame every x frames') { |o| options[:include_rate] = o }
    opt.on('-s', '--frame_start_offset=MANDATORY', 'frame start offset seconds') { |o| options[:start_offset] = o }
    opt.on('-d', '--step=MANDATORY', 'forward = 1 or rewind = -1') { |o| options[:direction] = o }


    # TODO: start_frame? end_frame?

    opt.on('-h', '--help', 'print usage') do
        puts opt
        exit
    end
end

begin
    optparse.parse!

    #Now raise an exception if we have not found a host option
    mandatory = [:max_frame, :include_rate, :start_offset, :direction]                             # Enforce the presence of
    missing = mandatory.select{ |param| options[param].nil? }
    unless missing.empty?
        raise OptionParser::MissingArgument.new(missing.join(', '))
    end

rescue OptionParser::InvalidOption, OptionParser::MissingArgument    
    puts $!.to_s                                                        # Friendly output when parsing fails
    puts optparse
    exit
end

max_frame = options[:max_frame].to_i
include_rate = options[:include_rate].to_i
start_offset = options[:start_offset].to_i
reverse = options[:direction].to_i < 0 ? true : false

if max_frame < 0
    puts "Error: max_frame SHOULD be > 0 - abort"
    return
end

if include_rate < 0
    puts "Error: include_rate SHOULD be > 0 - abort"
    return
end


cnt = include_rate

max_frame.times do |i|

    if cnt == include_rate

        f = start_offset

        if reverse
            f -= i
        else
            f += i
        end

        print f.to_s + ","
    end

    cnt -= 1
    cnt = include_rate if cnt <= 0
end


