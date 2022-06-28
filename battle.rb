module PlayerAttributes
  require 'colorize'

  def self.included(klass)
    klass.extend(ClassMethods)
  end

  class PlayerMustHaveNameError < StandardError; end
  def initialize(*attrs)
    attrs = attrs.select {|a| a.is_a? Hash }.first
    raise PlayerMustHaveNameError unless attrs.keys.include? :name
    attrs.each do |attr, value|
      instance_variable_set("@#{attr}", value)
    end
  end

  module ClassMethods
    def has_attributes(*attrs)
      attr_accessor *attrs
    end
  end
end

module PlayerActions
  class ActionNotImplementedError < StandardError; end

  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def has_actions(*actions)
      actions.each do |action|
        self.send(:define_method, action) do
          raise ActionNotImplementedError, "this action has not been given to this player yet"
        end
        self.default_player_actions << action
      end
    end

    def all_player_actions
      DefaultPlayer.default_player_actions
    end

    def has_action(action, &block)
      self.send(:define_method, action , block)
      self.player_actions << action
    end
  end

  def random_action(targets)
    self.send(self.class.all_player_actions.sample, targets)
  end

  def calculate_damage(attacker, damage_mod, target, can_dodge = true)
    damage = 0

    if can_dodge == true
      # See if the target dodges the attack
      random = Random.new.rand(1..10)
      return "but #{target.name} dodges and takes 0 damage" if random <= target.dodge
    end

    # Calculate damage based on attacker strength and target block
    damage = damage_mod * attacker.strength

    # Minus block from attack and then reduce block by attack amount (can't go negative)
    block_difference = target.block.clone - damage.clone
    damage_result = "for #{damage.clone} but #{target.name} blocks #{target.block.clone} " if target.block > 0

    damage -= target.block

    # reduce block by damage done
    target.block = block_difference 
    target.block = 1 if target.block <= 0

    damage = 0 if damage < 0
    target.current_health -= damage
    
    damage_result += "and #{target.name} takes #{damage} damage"
  end
end

class DefaultPlayer
  @default_player_actions = []
  class << self
    attr_accessor :default_player_actions
  end  
  include PlayerAttributes
  include PlayerActions
  
  has_attributes :name, :current_health, :max_health, :strength, :damage, :block, :dodge
  has_actions :attack, :prepare

  def pick_target(targets)
    target = targets[Random.new.rand(0..(targets.size-1))]
  end

  def attack(targets)
    target = pick_target(targets)
    damage_result = calculate_damage(self, 3, target)

    puts "#{self.name} attacks #{target.name} #{damage_result}"
    puts "#{target.name} now has #{target.current_health}/#{target.max_health}HP".light_blue
  end

  def prepare(var)
    self.block += 5
    puts "#{self.name} hunkers down to prepare for the coming attacks, their block goes up to #{self.block}"
  end
end
  
class Human < DefaultPlayer
  @player_actions = []
  class << self
    attr_accessor :player_actions
  end

  has_action :talk_their_way_out_of_it do |targets|
    target = pick_target(targets)
    puts "#{self.name} tries to talk their way out of an encounter with #{target.name}..."
    
    damage_result = calculate_damage(target, 2, self, false)

    random = Random.new.rand(1..5)
    if random <= 2
      puts "#{self.name} failed, #{target.name} attacks #{damage_result}"
    else
      self.current_health += 15
      puts "#{self.name} somehow succeeded, and healed 15HP."
    end
  end

  has_action :throws_potion do |targets|
    puts "#{self.name} has thrown a potion in the arena..."

    targets.each do |target|
      puts "...#{calculate_damage(self, 10, target)}"
    end

  end

  def self.all_player_actions
    player_actions + super
  end
end

class Dragon < DefaultPlayer
  @player_actions = []
  class << self
    attr_accessor :player_actions
  end
  
  has_action :fire_breath do |targets|
    action_damage = 6 * self.strength

    targets.each do |target|
      target.current_health -= action_damage
    end

    puts "#{self.name} breaths fire over the arena dealing #{action_damage} damage to everyone else."
  end

  def self.all_player_actions
    player_actions + super
  end
end

class Giant < DefaultPlayer
  @player_actions = []
  class << self
    attr_accessor :player_actions
  end
  
  has_action :stomp do |targets|
    target = pick_target(targets)

    puts "#{self.name} stomps on #{target.name} #{calculate_damage(self, 5, target)}"
  end

  has_action :war_cry do |targets|
    puts "#{self.name} lets out a rallying war cry"
    random = Random.new.rand(1..10)
    if random <= 3 
      self.current_health -= 20
      puts "Everyone laughs at #{self.name}, they take #{10 * targets.size} damage from embarrassment"
    else
      self.block += 20
      puts "Everyone cowers before #{self.name}, #{self.name} bolsters themselves and increase their block by 20"
    end
  end

  def self.all_player_actions
    player_actions + super
  end
end

class Battle
  class TooManyPlayersError < StandardError; end
  class LastPlayerLeft < StandardError; end

  attr_reader :players
  def initialize(*players)

    @players = players
    puts "Battle has been initialized"
    puts "=" * 8
  end

  def shuffle_players
    players.shuffle
  end

  def check_if_dead(player)
    if player.current_health <= 0
      puts "#{player.name} has been eliminated".red
      `say #{player.name} has been eliminated` 
      players.delete(player)
    end
  end

  def player_update(players)
    puts "Totals:".light_blue
    players.each do |player|
      puts "#{player.name}: #{player.current_health}/#{player.max_health} HP and #{player.block} block".light_blue
      check_if_dead(player)
    end
    raise LastPlayerLeft, "#{players[0].name} is the last player remaining! VICTORY!!!" if players.size <= 1
    puts "=" * 8
  end


  def begin
    `say FIGHT`
    (1..100).each do |round|
      # `say Round #{round}`
      puts "Round #{round}".green
      players = shuffle_players

      players.each_with_index do |current, i|
        targets = players.clone 
        targets.delete_at(i)

        current.random_action(targets)
        puts "..."
      end
      
      player_update(players)
      # puts "press any key to continue to next round..."
      # gets
    end
  end
end

john = Human.new(name: "John", current_health: 80, max_health: 80, strength: 6, block: 5, dodge: 5)
dragon = Dragon.new(name: "Boromir", current_health: 125, max_health: 125, strength: 8, block: 5, dodge: 2)
evan = Human.new(name: "Evan", current_health: 100, max_health: 100, strength: 4, block: 5, dodge: 5)
stacy = Giant.new(name: "Stacy", current_health: 150, max_health: 150, strength: 10, block: 5, dodge: 1)

Battle.new(dragon, stacy, evan).begin

# TODO: 

# CHANGE ALL ATTACKS TO USE CALCULATE DAMAGE