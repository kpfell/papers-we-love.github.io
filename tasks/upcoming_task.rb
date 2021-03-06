require 'middleman-core/cli'
require 'date'
require 'erb'
require 'yaml'

require_relative '../lib/event-handler.rb'
require_relative '../lib/safe-parameterize.rb'

##
# Generate Upcoming Meetups post from chapters.yml via upcoming command
##
class Gen < Thor
  check_unknown_options!

  namespace :upcoming

  TEMPLATE = 'lib/templates/upcoming_meetups_template.erb'
  DEFAULT_DATA_FILE = 'data/meetup/chapters.yml'

  attr_reader :output

  def self.source_root
    ENV['MM_ROOT']
  end

  def self.exit_on_failure?
    true
  end

  desc 'upcoming', 'Create a post of meetups for the next month'
  method_option 'month',
                aliases: '-m',
                desc: 'Integer of the month to target, ex: 3 for March'

  method_option 'data',
                aliases: '-d',
                desc: 'YAML dump of Meetup.com chapter information'

  def upcoming
    month = options[:month].to_i || Time.now.month + 1
    next_month = date_next_month(month)
    make_template_vars(next_month)
    filename = options[:data] || DEFAULT_DATA_FILE
    @events = gather_events(filename, next_month)
    render(TEMPLATE)
    save
  end

  protected

  # Setup vars needed by erb template
  def make_template_vars(month)
    @month = month.strftime('%B')
    @title = "#{@month} Meetups"
    @slug = safe_parameterize(@title)
    @author = 'Joshua'
    @date = month.strftime('%Y-%m-%d')
  end

  # Generate a UTC time object for the month passed in or
  # for the next month from now
  def date_next_month(month)
    t = Time.now
    m = month || t.month + 1
    Time.utc(t.year, m, 1)
  end

  # We only want events that are in the month specified and current year.
  # We also filter out any events missing a venue.
  def gather_events(filename, date)
    chapters = YAML.load_file(filename)
    events = chapters.collect do |k,v|
      v['events'].select do |e|
        ed = Time.at(e['time'] / 1000)
        ed.month == date.month && ed.year == date.year && e.key?('venue')
      end
    end
    sort_events(events.reject(&:empty?).flatten).reverse
  end

  def render(template)
    b = binding
    ERB.new(File.read(template), 0, '', '@output').result b
  end

  def save
    filepath = File.join('source', "#{@date}-#{@slug}.html.markdown")
    File.write(filepath, @output)
  end

end
