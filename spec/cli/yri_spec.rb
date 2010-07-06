require File.dirname(__FILE__) + '/../spec_helper'

class YARD::CLI::YRI
  public :optparse, :find_object, :cache_object, :menu, :find_objects
end

describe YARD::CLI::Yardoc do
  before do
    @yri = YARD::CLI::YRI.new
    Registry.instance.stub!(:load)
  end
  
  describe '#find_object' do
    it "should use cache if available" do
      @yri.stub!(:cache_object)
      File.should_receive(:exist?).with('.yardoc').and_return(false)
      File.should_receive(:exist?).with('bar.yardoc').and_return(true)
      Registry.should_receive(:load).with('bar.yardoc')
      Registry.should_receive(:at).with('Foo').and_return('OBJ')
      @yri.instance_variable_set("@cache", {'Foo' => 'bar.yardoc'})
      @yri.find_object('Foo').should == 'OBJ'
    end
    
    it "should never use cache ahead of current directory's .yardoc" do
      @yri.stub!(:cache_object)
      File.should_receive(:exist?).with('.yardoc').and_return(true)
      Registry.should_receive(:load).with('.yardoc')
      Registry.should_receive(:at).with('Foo').and_return('OBJ')
      @yri.instance_variable_set("@cache", {'Foo' => 'bar.yardoc'})
      @yri.find_object('Foo').should == 'OBJ'
      @yri.instance_variable_get("@search_paths")[0].should == '.yardoc'
    end
  end
  
  describe '#cache_object' do
    it "should skip caching for Registry.yardoc_file" do
      File.should_not_receive(:open).with(CLI::YRI::CACHE_FILE, 'w')
      @yri.cache_object('Foo', Registry.yardoc_file)
    end
  end
  
  describe '#initialize' do
    it "should load search paths" do
      path = %r{/\.yard/yri_search_paths$}
      File.should_receive(:file?).with(%r{/\.yard/yri_cache$}).and_return(false)
      File.should_receive(:file?).with(path).and_return(true)
      File.should_receive(:readlines).with(path).and_return(%w(line1 line2))
      @yri = YARD::CLI::YRI.new
      spaths = @yri.instance_variable_get("@search_paths")
      spaths.should include('line1')
      spaths.should include('line2')
    end
  end

  def method_objects(*objects)
    objects.map {|mod,name,scope|
      nsp = CodeObjects::ModuleObject.new(:root, mod)
      CodeObjects::MethodObject.new(nsp, name, scope || :instance)
    }
  end

  describe '#menu' do
    before do
      @yri.stub!(:puts)
      @yri.stub!(:print)
    end

    def user_chooses(answer)
      $stdin.should_receive(:gets).and_return(answer)
    end

    def menu(*objects)
      @yri.menu method_objects(*objects)
    end

    it "should return correct choice" do
      user_chooses '2'
      menu([:A, :foo], [:B, :bar]).path.should == 'B#bar'
    end

    it "should abort if non-numerical choice" do
      user_chooses 'a'
      @yri.should_receive(:abort)
      menu
    end

    it "should abort if choice is an invalid number" do
      user_chooses '0'
      @yri.should_receive(:abort)
      menu
    end
  end

  describe '#find_objects' do
    before do
      Registry.stub!(:load)
      Registry.stub!(:load_all)
      File.should_receive(:exist?).and_return(true)
      @yri.instance_variable_set("@search_paths", ['.yardoc'])
    end

    def registry_contains(*objects)
      objects = method_objects(*objects) unless objects[0].is_a?(CodeObjects::Base)
      Registry.should_receive(:all).and_return objects
    end

    def find_objects(query)
      @yri.find_objects(query).map {|e| e.path }
    end

    def class_objects(*objects)
      objects.map {|mod,name,scope|
        nsp = mod == :root ? mod : CodeObjects::ModuleObject.new(:root, mod)
        CodeObjects::ClassObject.new(nsp, name, scope || :instance)
      }
    end

    it "should find methods with part of method name" do
      registry_contains [:A, :fan], [:B, :far, :class], [:B, :bub]
      find_objects('fa').should == %w{A#fan B.far}
    end

    it "should find methods with a regular expression" do
      registry_contains [:A, :read], [:B, :far], [:C, :car]
      find_objects('r$').should == %w{B#far C#car}
    end

    it "should find instance methods with Class#meth" do
      registry_contains [:A, :fan], [:A, :far, :class], [:B, :bub]
      find_objects('A#f').should == %w{A#fan}
    end

    it "should find class methods with Class.meth" do
      registry_contains [:A, :fan], [:A, :far, :class], [:B, :bub]
      find_objects('A.f').should == %w{A.far}
    end

    it "should find non-methods with capitalized query" do
      classes = class_objects [:root, :Awesome], [:root, :Dude], [:So, :Awesome]
      meths = method_objects([:Awesome, :fan], [:Dude, :bub])
      registry_contains  *(meths + classes)
      Registry.stub!(:all).with(:method).and_return meths
      find_objects('Awe').should == %w{Awesome So::Awesome}
    end

    it "should return empty if no matches" do
      registry_contains [:A, :fan]
      find_objects('blah').should == []
    end
  end
end