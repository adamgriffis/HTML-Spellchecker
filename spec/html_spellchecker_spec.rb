# encoding: UTF-8
path = File.expand_path(File.dirname(__FILE__) + "/../lib/")
$LOAD_PATH.unshift(path) unless $LOAD_PATH.include?(path)
require "html_spellchecker"


describe HTML_Spellchecker do
  let(:checker) { HTML_Spellchecker.english(true) }

  it "doesn't modify correct sentences" do
    correct = "<p>This is a sentence with correct words.</p>"
    results = checker.spellcheck(correct)

    results[:html].should == correct
    results[:details].should == {error_count: 0}
  end

  it "marks spelling errors" do
    incorrect = "<p>xzqwy is not a word!</p>"
    results = checker.spellcheck(incorrect)

    results[:html] == "<p><mark class=\"misspelled\">xzqwy</mark> is not a word!</p>"
    results[:details].should == {"xzqwy" => 1, error_count: 1}
  end

  it "accepts new words" do 
    checker.add_word('bleghhhh')
    checker.add_word('xzqwy')
    correct = "<p>bleghhhh is not a word!</p>"
    results = checker.spellcheck(correct)

    results[:html].should == correct
    results[:details].should == {error_count: 0}
  end

  it "removes existing words" do 
    checker.remove_word('word')
    incorrect = "<p>This is not a word!</p>"
    results = checker.spellcheck(incorrect)

    results[:html].should == "<p>This is not a <mark class=\"misspelled\">word</mark>!</p>"
    results[:details].should == {"word" => 1, error_count: 1}
  end

  it "doesn't try to spellcheck code tags" do
    txt = "<code>class Foo\ndef hello\nputs 'Hi'\nend\nend</code>"
    results = checker.spellcheck(txt)

    results[:html].should == txt
    results[:details].should == {error_count: 0}
  end

  it "handles quotation marks" do 
    txt = "<p>She said, \"Hello, Adam.\"</p>"
    results = checker.spellcheck(txt)

    results[:html].should == txt
    results[:details].should == {error_count: 0}
  end

  it "handles titles and salutations" do 
    txt = "<p>Dr. Julie Smith, PhD</p>"
    results = checker.spellcheck(txt)

    results[:html].should == txt
    results[:details].should == {error_count: 0}
  end

  it "handles accent marks" do 
    txt = "<p>She's my fiancé.</p>"
    
    results = checker.spellcheck(txt)

    results[:html].should == txt
    results[:details].should == {error_count: 0}
  end

  it "can use different dictionnaries" do
    french_text = "<p>Ceci est un texte correct, mais xzqwy n'est pas un mot</p>"
    expected = french_text.gsub('xzqwy', '<mark class="misspelled">xzqwy</mark>')
    results = HTML_Spellchecker.french.spellcheck(french_text)

    results[:html].should == expected
    results[:details].should == {'xzqwy' => 1, error_count: 1}
  end

  it "can spellcheck nested tags" do
    txt = "<p>This is <strong>Important and <em>xzqwy</em></strong>!</p>"
    results = checker.spellcheck(txt)

    results[:html].should == txt.gsub('xzqwy', '<mark class="misspelled">xzqwy</mark>')
    results[:details].should == {'xzqwy' => 1, error_count: 1}
  end

  it "does not mangle spaces between 2 incorrect words" do
    txt = "<p>ttt yyy zzz</p>"
    expected = "<p>ttt yyy zzz</p>".gsub(/(\w{3})/, '<mark class="misspelled">\1</mark>')
    results = checker.spellcheck(txt)

    results[:html].should == expected
    results[:details].should == {'ttt' => 1, 'yyy' => 1, 'zzz' => 1, error_count: 3}
  end

  it "keeps <, > and & untouched" do
    txt = "<p>Inferior: &lt;</p><p>Superior: &gt;</p><p>Ampersand: &amp;</p>"
    results = checker.spellcheck(txt)

    results[:html].should == txt
    results[:details].should == {error_count: 0}
  end

  it "preserves accents" do
    txt = "<p>café caf&eacute;</p>"
    results = HTML_Spellchecker.french.spellcheck(txt)

    results[:html].should_not =~ /misspelled/
    results[:details].should == {error_count: 0}
  end

  it "does not split words with a quote" do
    txt = "<p>It doesn't matter</p>"
    results = checker.spellcheck(txt)

    results[:html].should == txt
    results[:details].should == {error_count: 0}
  end
end
