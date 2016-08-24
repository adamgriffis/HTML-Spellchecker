# Encoding: UTF-8

require "hunspell-ffi"
require "nokogiri"
require "set"


class HTML_Spellchecker
  def self.english(rebuild=false)
    if rebuild || @english.nil?
      @english = self.new("dictionaries/en_US.aff", "dictionaries/en_US.dic")
    end

    @english
  end

  def self.french(rebuild=false)
    if rebuild || @french.nil?
      @french = self.new("dictionaries/fr_FR.aff", "dictionaries/fr_FR.dic")
    end

    @french
  end

  def initialize(aff, dic)
    @dict = Hunspell.new(aff, dic)
  end

  def add_word(word)
    @dict.add(word)
  end

  def remove_word(word)
    @dict.remove(word)
  end

  def check_word(word)
    @dict.check(word)
  end

  def spellcheck(html)
    results = {}
    details_hash = {}

    results[:html] = Nokogiri::HTML::DocumentFragment.parse(html).spellcheck(@dict, details_hash)

    details_hash[:error_count] = details_hash.keys.length

    results[:details] = details_hash

    results
  end

  class <<self
    attr_accessor :spellcheckable_tags
  end
  self.spellcheckable_tags = Set.new(%w(p ol ul li div header article nav section footer aside dd dt dl
                                        span blockquote cite q mark ins del table td th tr tbody thead tfoot
                                        a b i s em small strong hgroup h1 h2 h3 h4 h5 h6))
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
    HTML_Spellchecker.spellcheckable_tags.include? name
  end
end

class Nokogiri::XML::Text
  WORDS_REGEXP = RUBY_VERSION =~ /^1\.8/ ? /(&\w+;)|([\w']+)/ : /(&\p{Word}{2,3};)|([\p{Word}']+)/
  ENTITIES = ["&gt;", "&lt;", "&amp;", "&nbsp;"]

  def spellcheck(dict, results)
    to_xhtml(:encoding => 'UTF-8').gsub(WORDS_REGEXP) do |word|
      if ENTITIES.include?(word) || dict.check(word)
        word
      else
        # this isn't a great workaround but can't get hunspell to recognize plural posessives which are pretty common so test that this word isn't
        # correct without the traling apostophe
        if word.end_with?("s'") && dict.check(word[0..-2])
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
