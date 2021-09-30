require 'optparse'
require 'date'
#require 'thread'

require 'fileutils'


VERSION = "0.3"

#---------------------
TARGET_FRAME_RATE = 30

TARGET_FILE_EXT = ".mp4"
TARGET_BASE_FILE_NAME = "output"
TARGET_FILE_NAME = TARGET_BASE_FILE_NAME + TARGET_FILE_EXT

#---------------------
module Logger

    attr_accessor(:verbosity)

    module DEBUG_LEVEL

        ALL = 0
        INFO = 1
        DUMP = 2
    end

    #---------------------
    def log(str, severity = DEBUG_LEVEL::ALL)

        puts str if severity <= @verbosity
    end

end

#---------------------
class SlowMoGen

    include Logger

    # SlowMoGen.new(options[:infile], options[:inrate], options[:outlist], options[:output], options[:verbosity], options[:cleanup])
    #def initialize(infile, inrate, outlist, output, verbosity, cleanup)
    def initialize(infile, outlist, output, verbosity, cleanup)
        
        @in_file = infile
#        @in_rate = 0
        @outlist_file = outlist
        @output_path = output
        @cleanup = cleanup

        @app_dir = Dir::pwd

        @verbosity = verbosity.to_i

        log("*** #{self.class}, version #{VERSION} ***")

        if File.exist? @in_file
            puts "> in file = '#{@in_file}'"
        else
#            puts "Error: in file '#{@in_file}' does not exist! - abort"
            raise ArgumentError("in file '#{@in_file}' does not exist")
        end

        if File.directory?(@output_path)
            puts "> working and output dir: " + @output_path
        else
#            puts "Error: directory '#{@output_path}' does not exist! - abort"
            raise ArgumentError("directory '#{@output_path}' does not exist")
        end

        '''if @in_rate > 1
            puts "> in frame rate = #{@in_rate}"
        else
            raise ArgumentError("Illegal rate delivered")
        end'''

        # TODO: check output_list existance

        puts "> cleanup = " + @cleanup.to_s

#        puts "> use buffer_size = #{@buffer_size}"

    end

    def go

        log(DateTime.now.strftime("%H:%M:%S.%L") + " START", DEBUG_LEVEL::DUMP)

        Dir.chdir(@output_path).to_s

        if Dir::pwd != @app_dir

            log(DateTime.now.strftime("%H:%M:%S.%L") + "cd -> " + Dir::pwd, DEBUG_LEVEL::DUMP)

            handle_cleanup      # prior garbage collection

#            res = extract_video_frame_rate

#            (res = handle_decoding) if res
            res = handle_decoding

            (res = handle_frames_filtering) if res

            (res = handle_encoding) if res

            puts "### check #{TARGET_FILE_NAME} file in #{@output_path} ###" if res

            handle_cleanup(true, true)      # garbage collection

        else
            log("Error: failed to chdir into '#{@output_path}'", DEBUG_LEVEL::ALL)
        end

        log(DateTime.now.strftime("%H:%M:%S.%L") + " END", DEBUG_LEVEL::DUMP)

    end

    private

    #---------------------
    def handle_cleanup(force=true, all=true)

        if @cleanup || force

            log(DateTime.now.strftime("%H:%M:%S.%L") + " -------> cleanup", DEBUG_LEVEL::ALL)
            system("rm -f " + @output_path + "/*.bmp")

            system("rm -f " + @output_path + "/*.pmb") if all
        end
    end

    #---------------------
    def extract_video_frame_rate

        log(DateTime.now.strftime("%H:%M:%S.%L") + " -------> extract video frame rate", DEBUG_LEVEL::ALL)

        # use ffprobe to extract video frame rate before manipulating the stream
        @in_rate = `ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate #{@in_file} | grep r_frame_rate=`.split('=').last.split("\/").first.to_i

        puts "*** video-in frame rate = #{@in_rate} fps"

        return @in_rate > 0
    end

    #---------------------
    def handle_decoding

        log(DateTime.now.strftime("%H:%M:%S.%L") + " -------> decoding", DEBUG_LEVEL::ALL)

        #cmd = "ffmpeg -i #{@in_file} -r #{@in_rate} $filename%d.bmp"
        cmd = "ffmpeg -i #{@in_file} $filename%d.bmp"
        res = system(cmd)

        log(DateTime.now.strftime("%H:%M:%S.%L") + " ERROR: decoding FAILED - abort", DEBUG_LEVEL::ALL) if res == false # failed...
        return res
    end

    #---------------------
    def handle_frames_filtering

        log(DateTime.now.strftime("%H:%M:%S.%L") + " -------> frames filtering", DEBUG_LEVEL::ALL)

        instructions = File.read(@app_dir + "\/" + @outlist_file)
#        puts instructions

        frames = instructions.split(',')
#        puts frames.to_s

        frames.each do |f|
            o = f + ".bmp"
            if File.exist?(o)
#                puts "...rename #{o}"
                n = f + ".pmb"
                File.rename(o, n)
            end
        end

        # delete all .bmp files
        handle_cleanup(true, false)

        # rename .pmb back to bmp, this time sequentially

        cnt = 1
# TEST!!!        `ls *.pmb`.split(".pmb\n").map { |i| i.to_i }.sort.each do |j|\
        frames.each do |j|
            f = j.to_s + ".pmb"
            n = cnt.to_s + ".bmp"
#            puts "...rename #{f} -> #{n}"
#            File.rename(f, n)
            #puts @output_path + n

            FileUtils.copy(f, @output_path + n) if File.exist?(f) # WORKAROUND!
            cnt += 1
        end

        return true
    end

    #---------------------
    def handle_encoding

        log(DateTime.now.strftime("%H:%M:%S.%L") + " -------> encoding", DEBUG_LEVEL::ALL)

        # TODO

        # ffmpeg -framerate 100 -i %d.bmp output.mpg
        #cmd = "ffmpeg -y -framerate #{@in_rate} -i %d.bmp #{TARGET_FILE_NAME}"
        cmd = "ffmpeg -y -i %d.bmp -r #{TARGET_FRAME_RATE} #{TARGET_FILE_NAME}"
        res = system(cmd)

        log(DateTime.now.strftime("%H:%M:%S.%L") + " ERROR: encoding FAILED - abort", DEBUG_LEVEL::ALL)if res == false # failed...

        return res
    end
end

#----------------------------
# MAIN
#----------------------------

options = {}

optparse = OptionParser.new do |opt|

    opt.on('-f', '--in_file=MANDATORY', 'input file path') { |o| options[:infile] = o }
#    opt.on('-r', '--in_rate=MANDATORY', 'input frame rate') { |o| options[:inrate] = o }
    opt.on('-l', '--out_frames_list=MANDATORY', 'output frames list') { |o| options[:outlist] = o }

    opt.on('-g', '--cleanup=OPTIONAL', TrueClass, 'indicates whether to cleanup any existing frame files before start') { |o| options[:cleanup] = o.nil? ? false : o }

    opt.on('-o', '--output=MANDATORY', 'output directory') { |o| options[:output] = o }
    opt.on('-v', '--verbose=OPTIONAL', 'trace level [0..2]. default = 0') { |o| options[:verbosity] = o }

    opt.on('-h', '--help', 'print usage') do
        puts opt
        exit
    end
end

begin
    optparse.parse!

    #Now raise an exception if we have not found a host option
#    mandatory = [:infile, :inrate, :outlist, :output]              # Enforce the presence of
    mandatory = [:infile, :outlist, :output]              # Enforce the presence of
    missing = mandatory.select{ |param| options[param].nil? }
    unless missing.empty?
        raise OptionParser::MissingArgument.new(missing.join(', '))
    end

    if options[:verbosity].nil?
        options[:verbosity] = 0
    end

rescue OptionParser::InvalidOption, OptionParser::MissingArgument    
    puts $!.to_s                                                      # Friendly output when parsing fails
    puts optparse
    exit
end


begin

    # example:
    # ruby ./slowmo_gen.rb -f /Users/rotemcohen/dev/cloudinary/server/spec/videos/hvflipped.mov -r 100 -o /tmp -l frames.txt -v 2 -g true

    #smg = SlowMoGen.new(options[:infile], options[:inrate], options[:outlist], options[:output], options[:verbosity], options[:cleanup])
    smg = SlowMoGen.new(options[:infile], options[:outlist], options[:output], options[:verbosity], options[:cleanup])
    smg.go

''' TBD
rescue ArgumentError => e
    puts "Exception caught(#{e.class}): '#{e.message}'" '''
end

#-------------------------------------------------------------------
#-------------------------------------------------------------------
#-------------------------------------------------------------------
