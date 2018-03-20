#!/usr/bin/env ruby
require 'optparse'
require 'optparse/time'
require 'ostruct'
require 'pp'
require 'fileutils'
require 'json'
class Inputparser
  @options = {
  #  'clientNum' => { 'flag' => 'n', 'desc' => 'Number of clients', 'default' => 150, 'cast' => OptionParser::DecimalInteger },
    'port' => { 'flag' => 'p', 'desc' => 'Sets the port for docker registry ', 'default' => '5000' },
  #  'queue' => { 'flag' => 'q', 'desc' => 'Sets the queue to a specfic', 'default' => 'main' },
    'yes' => { 'type' => 'switch', 'flag' => 'y', 'desc' => 'Let the script answer yes to all questions', 'default' => false },
      'name' => { 'flag' => 'n', 'desc' => 'Give the tag of the docker image you want to export', 'default' => 'undefined' },
      'create' => { 'type'=>'switch', 'flag' => 'c', 'desc' => 'Create a Singularityfile', 'default' => false },
      'writable' => { 'type'=>'switch', 'flag' => 'w', 'desc' => 'Build a writable singularity image', 'default' => false }
  }

  def self.parse(args)
    @options.each do |_k, v|
      v['cast'] = String if v['cast'].nil?
      v['type'] = 'option' if v['type'].nil?
    end # set normal casting to String and type to "option"
    result = {}
    OptionParser.new do |opts|
      opts.banner = 'Usage: dock2sing.rb [options] '
      opts.on('-h', '--help', 'Display this screen') do
        puts opts
        exit
      end
      @options.each do |k, v|
        result[k] = v['default']
        if v['type'] == 'option'
          opts.on("-#{v['flag']} [operand]", "--#{k} [operand]", v['cast'], v['desc']) { |operand| result[k] = operand }
        else
          opts.on("-#{v['flag']}", "--#{k}", v['cast'], v['desc']) { result[k] = !v['default'] }
        end
      end
    end.parse!(args)
    # ask for user input
    pp result
    if result['yes'] == false
      pp 'Run with these Options?[y/n]'
      answer = gets.chomp
      exit unless answer == 'y' || answer == 'Y'
    end
    result # return options
  end # self.parse()

end # class Myparser

class Dock2Sing
  def initialize
    @options=Inputparser.parse(ARGV)
    setupRegistry()
  end
  def setupRegistry
    #pull the registry
    %x(docker pull registry:2)
    #check if the container exists, start it if it does, create it if needed
    `docker run -d -p 5000:#{@options["port"]} --restart=always --name dock2singRegistry registry:2` if  `docker ps -a --format "{{.Names}} " --filter "name=dock2singRegistry"`==""
    `docker start dock2singRegistry ` if  `docker ps --format "{{.Names}} " --filter "name=dock2singRegistry"`==""
  end
  def pushToRegistry()
    throw 'Error: no name for a image defined with -n/ --name' unless @options['name']!='undefined'
    puts `docker tag #{@options['name']} localhost:5000/all/#{@options['name']}`
    puts `docker push localhost:5000/all/#{@options['name']} `
  end
  def createSingImage
    throw '--create is not set and no Singularityfile exists' unless File.exist?("Singularityfile") || @options['create']
      if @options['create'] then
      singfile = "Bootstrap: docker\nFrom: all/#{@options['name']}:latest\nRegistry: localhost:5000"
      File.open("Singularityfile", 'w') { |file| file.write(singfile) }
      end
      puts `SINGULARITY_NOHTTPS=true SINGULARITY_DISABLE_CACHE=true singularity build -s #{@options['name']} Singularityfile`
      puts `singularity build #{@options['writable'] ? "--writable":""} #{@options['name']}.simg #{@options['name']}`

  end

  def dock2sing()
    pushToRegistry()
    createSingImage()
  end
end # class dock2sing
test=Dock2Sing.new
test.dock2sing()
