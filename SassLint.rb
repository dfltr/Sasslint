require '../sass/lib/sass.rb'
require 'pp'

class SassLint < Sass::Tree::Visitors::Base
  def initialize(file, options={:recursive => false})
    if File.directory?(file)
      Dir.foreach(file){ |f|
        #Parse sass & scss files, recurse directories if -r && not . nor ..
        if ['.sass', '.scss'].index(File.extname(f)) || (File.directory?(f) && options[:recursive] && !['.', '..'].index(f))
          puts "LINTING " + file + '/' + f
          SassLint.new(file + '/' + f, options)
        end
      }
      return
    end

    sass = Sass::Engine.for_file(file, { :cache => false })
    tree = sass.to_tree
    @rules = []
    @warnings = []
    dupes = []

    #Parse the SASS tree
    visit tree

    puts "\n%d rules parsed in %s\n\n" % [@rules.length, file]

    @rules.each do |r|
      #puts r[:rule]

      #Find duplicate CSS rules
      if dupes.index r[:rule]
        orig = @rules[@rules.index{|search| search[:rule] == r[:rule]}]

        @warnings.push "%d: Duplicate rule: %s\n    Original on line: %d" % [r[:line], r[:rule], orig[:line]]
      else
        dupes.push r[:rule]
      end
    end

    if @warnings.length > 0
      @warnings.each do |w|
        puts w
      end
    else
      puts 'All clear. Go forth and prosper.'
    end
  end

  #Note: This only hits top-level nodes, recursion is handled by append_child_rules
  def visit_rule(node)
    rules = node.rule[0].split(',')

    rules.each do |rule|
      append_child_rules(node, rule.strip)
    end
  end

  def append_child_rules(node, chain)
    no_child_rules = true

    node.children.each do |child|
      if self.node_name(child) == 'rule'
        no_child_rules = false

        new_rules = child.rule[0].split(',')

        new_rules.each do |new_rule|
          new_rule.strip!
          new_chain = new_rule.index('&') == 0 ? new_rule[1..-1] : ' ' + new_rule
          append_child_rules(child, chain + new_chain)
        end
      end
    end

    if no_child_rules
      @rules.push({
        :line => node.line,
        :rule => chain
      })
    end
  end
end
