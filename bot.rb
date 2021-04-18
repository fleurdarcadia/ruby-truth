require 'digest'

require 'discordrb'


module Labeler
  def label
    Digest::MD5.hexdigest(self.to_s)[...7]
  end
end

class Truth
  include Labeler

  attr_reader :id, :prefix, :text

  def initialize prefix, text
    @prefix = prefix
    @text = text
    @id = self.label
  end

  def format
    "```diff
#{@prefix}(#{@id}) #{@text}
```"
  end

  def to_s
    @text
  end
end

class Blue < Truth
  @@prefix = '+ '

  def self.prefix
    @@prefix
  end

  def initialize text
    super @@prefix, text
  end

  def format
    "Stated in blue:\n#{super}"
  end
end

class Red < Truth
  @@prefix = '- '

  def self.prefix
    @@prefix
  end

  def initialize text
    super @@prefix, text
  end

  def format
    "Stated in red:\n#{super}"
  end
end

class Joiner
  def self.join(prefix, truths)
    prefixed = truths.map {|truth| "#{prefix}(#{truth.id}) #{truth.text}"}.join "\n"
    "```diff\n#{prefixed}\n```"
  end
end

class Invalidator
  attr_reader :blue, :reds

  def initialize blue, reds
    @blue = blue
    @reds = reds
  end

  def format
  "#{@blue.format}
is invalidated by the following red truths:
#{Joiner.join(Red.prefix, @reds)}"
  end
end

class Game
  attr_reader :blue_truths, :red_truths, :invalidations

  def initialize
    @blue_truths = []
    @red_truths = []
    @invalidations = []
  end

  def add_blue_truth text
    @blue_truths << Blue.new(text)
    @blue_truths[-1].format
  end

  def add_red_truth text
    @red_truths << Red.new(text)
    @red_truths[-1].format
  end

  def invalidate blue, reds
    @invalidations << Invalidator.new(blue, reds)
    @invalidations[-1].format
  end
end

class Command
  attr_reader :name

  def initialize name, game
    @name = name
    @game = game
  end

  def register bot
    bot.command @name do |event, *text|
      self.execute(@game, event, *text)
    end
  end

  private

  def execute
  end
end

class RegisterBlueTruth < Command
  def initialize game
    super :blue, game
  end

  def execute game, event, *text
    event.message.delete
    game.add_blue_truth(text.join ' ')
  end
end

class RegisterRedTruth < Command
  def initialize game
    super :red, game
  end

  def execute game, event, *text
    event.message.delete
    game.add_red_truth(text.join ' ')
  end
end

class ListBlueTruths < Command
  def initialize game
    super :blues, game
  end

  def execute game, event, *text
    Joiner.join(Blue.prefix, game.blue_truths)
  end
end

class ListRedTruths < Command
  def initialize game
    super :reds, game
  end

  def execute game, event, *text
    Joiner.join(Red.prefix, game.red_truths)
  end
end

class Invalidate < Command
  def initialize game
    super :invalidate, game
  end

  def execute game, event, blue_id, *red_ids
    blue_index = game.blue_truths.find_index {|truth| truth.id == blue_id}
    red_indices = red_ids.map do |red_id|
      game.red_truths.find_index {|truth| truth.id == red_id}
    end

    if blue_index.nil? or red_indices.any? {|index| index.nil?}
      return "Could not find one of the specified truths."
    end
  
    game.invalidate(
      game.blue_truths[blue_index],
      red_indices.map {|index| game.red_truths[index]})
  end
end

class Invalidations < Command
  def initialize game
    super :invalidations, game
  end

  def execute game, event
    game.invalidations
      .map {|inv| inv.format}
      .join "\n"
  end
end

class GameManager
  def initialize cmd_bot, cmds
    @bot = cmd_bot
    @game = Game.new

    cmds.each {|cmd| cmd.new(@game).register(@bot)}
  end

  def run
    @bot.run
  end
end

COMMANDS = [
  RegisterRedTruth,
  RegisterBlueTruth,
  ListRedTruths,
  ListBlueTruths,
  Invalidate,
  Invalidations,
]

bot = Discordrb::Commands::CommandBot.new(
  prefix: '!',
  client_id: ENV['CLIENT_ID'],
  token: ENV['TOKEN']
)

gm = GameManager.new(bot, COMMANDS)

gm.run
