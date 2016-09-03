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
    txt = "<code>class Foo\ndef hello\nputs 'Hi'\nend\nend</code><script>var code = 'here';</script><style>.dmb-rule{display: none!}</style>"
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
    txt = "<p>Dr. Julie Smith, PhD M.Ed.</p>"
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

  it "handles weird encoded quotes" do 
    txt = "<a>Dedicating the dogs' dog's the ‘Rock’</a><span>Say ‘yes’ or ‘yes, please’ to weird quotes</span><p>Retracing our forefather's sacrificial steps</p>"

    results = checker.spellcheck(txt)

    results[:html].should == txt
    results[:details].should == {error_count: 0}
  end

  it "ignores email addresses and URLs" do 
    txt = "Here's an email test@test.com, you can reach it at http://www.test.com/email or https://www.test.com/secure"

    results = checker.spellcheck(txt)

    # we strip the email and URL out, but we ignore the marked HTML so it's fine
    results[:html].should == "Here's an email  , you can reach it at   or  "
    results[:details].should == {error_count: 0}
  end

  it "can deal with weirdos who use HTML entities in the middle of sentences" do 
    txt = "I can't use spaces&nbsp;like a normal person."

    results = checker.spellcheck(txt)

    results[:html].should == "I can't use spaces like a normal person."
    results[:details].should == {error_count: 0}
  end

  it "handles hyphenated words" do 
    txt = "Here's a mis-spelled word, miss. It's well-known that this is an accepted usage, it's matter-of-fact at this point. Drop your pre-conceived, pre-packaged, state-of-the-art notions at the door. It's mid-July after all."

    results = checker.spellcheck(txt)

    results[:html].should == "Here's a <mark class=\"misspelled\">mis-spelled</mark> word, miss. It's well-known that this is an accepted usage, it's matter-of-fact at this point. Drop your pre-conceived, pre-packaged, state-of-the-art notions at the door. It's mid-July after all."
    results[:details].should == {'mis-spelled' => 1, error_count: 1}
  end
end
