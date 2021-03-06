# Encoding: UTF-8

require "ffi/hunspell"
require "nokogiri"
require "set"
require 'htmlentities'

EMAIL_REGEX = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b/i
LINK_REGEX = /\b(https?:\/\/([-\w\.]+)+(:\d+)?(\/([\w\/_\.]*(\?\S+)?)?)?)\b/i

class HTML_Spellchecker

  def self.entity_coder
    @@entity_coder ||= HTMLEntities.new
  end
  def self.english(rebuild=false)
    if rebuild || @english.nil?
      @english = self.new("en_US")
    end
    @english
  end

  def self.french(rebuild=false)
    if rebuild || @french.nil?
      @french = self.new("fr_FR")
    end
    @french
  end

  def self.root
     Gem.datadir('html_spellchecker')
  end

  def initialize(lang)
    FFI::Hunspell.directories = [File.expand_path(File.join(File.dirname(__FILE__), "../dictionaries/"))]
    @dict = FFI::Hunspell.dict(lang)
  end

  def add_word(word)
    @dict.add(word)
  end

  def remove_word(word)
    @dict.remove(word)
  end

  def check_word(word)
    puts "Checking word: #{word}"
    @dict.check?(word)
  end

  def spellcheck(html)
    results = {}
    details_hash = {}

    results[:html] = Nokogiri::HTML::DocumentFragment.parse(html).spellcheck(@dict, details_hash)

    details_hash[:error_count] = details_hash.keys.length

    results[:details] = details_hash

    results
  end

  def close_dict
    @dict.close if @dict
  end

  class <<self
    attr_accessor :spellcheckable_tags, :skipable_tags
  end
  self.spellcheckable_tags = Set.new(%w(p ol ul li div header article nav section footer aside dd dt dl
                                        span blockquote cite q mark ins del table td th tr tbody thead tfoot
                                        a b i s em small strong hgroup h1 h2 h3 h4 h5 h6 body))
  self.skipable_tags = Set.new(%w(script style))
end

class Nokogiri::HTML::DocumentFragment
  def spellcheckable?
    true
  end
end

class Nokogiri::XML::Node
  def spellcheck(dict, results)
    if spellcheckable?
      inner = children.map {|child| child.spellcheck(dict, results) }.join
      children.remove
      add_child Nokogiri::HTML::DocumentFragment.parse(inner)
    end
    to_html(:indent => 0)
  end

  def spellcheckable?
    #name != "script"
    #puts "Spellcheckable? #{name}"
    #true
    #HTML_Spellchecker.spellcheckable_tags.include? name
    !HTML_Spellchecker.skipable_tags.include? name
  end
end

class Nokogiri::XML::Text
  WORDS_REGEXP = RUBY_VERSION =~ /^1\.8/ ? /(&\w+;)|([\w']+)/ : /(&#?\p{Word}{2,3};)|([\p{Word}+'-]+)/
  ENTITIES = ["&gt;", "&lt;", "&amp;", "&nbsp;", "-"]

  def spellcheck(dict, results)
    text = to_xhtml(:encoding => 'UTF-8')

    text = HTML_Spellchecker.entity_coder.decode(text)

    text.gsub!(EMAIL_REGEX, ' ')
    text.gsub!(LINK_REGEX, ' ')

    text.gsub(WORDS_REGEXP) do |word|
      #puts "Checking word: #{word}"
      if ENTITIES.include?(word) || dict.check?(word)
        word
      else
        # this isn't a great workaround but can't get hunspell to recognize plural posessives which are pretty common so test that this word isn't
        # correct without the traling apostophe
        if word.end_with?("s'") && dict.check?(word[0..-2])
          word
        else
          # add word to results hash, increment occurrence count
          results[word] ||= 0
          results[word] += 1

          "<mark class=\"misspelled\">#{word}</mark>"
        end
      end
    end
  end
end
