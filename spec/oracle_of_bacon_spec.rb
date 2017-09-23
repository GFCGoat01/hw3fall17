require 'oracle_of_bacon'

#require 'byebug'
require 'fakeweb'
require 'spec_helper'

describe OracleOfBacon do
  before(:all) { FakeWeb.allow_net_connect = false }
  describe 'instance' do
    before(:each) { @orb = OracleOfBacon.new('fake_api_key') }
    describe 'when new' do
      subject { @orb }
      it { should_not be_valid }
    end
    describe 'when only From is specified' do
      subject { @orb.from = 'Carrie Fisher' ; @orb }
      it { should be_valid }
      its(:from) { should == 'Carrie Fisher' }
      its(:to)   { should == 'Kevin Bacon' }
    end
    describe 'when only To is specified' do
      subject { @orb.to = 'Ian McKellen' ; @orb }
      it { should be_valid }
      its(:from) { should == 'Kevin Bacon' }
      its(:to)   { should == 'Ian McKellen'}
    end
    describe 'when From and To are both specified' do
      context 'and distinct' do
        subject { @orb.to = 'Ian McKellen' ; @orb.from = 'Carrie Fisher' ; @orb }
        it { should be_valid }
        its(:from) { should == 'Carrie Fisher' }
        its(:to)   { should == 'Ian McKellen'  }
      end
      context 'and the same' do
        subject {  @orb.to = @orb.from = 'Ian McKellen' ; @orb }
        it { should_not be_valid }
      end
    end
  end
  describe 'parsing XML response' do
    describe 'for a normal match' do
      subject { OracleOfBacon::Response.new(File.read 'spec/graph_example.xml') }
      its(:type) { should == :graph }
      its(:data) { should == ['Carrie Fisher', 'Under the Rainbow (1981)',
                              'Chevy Chase', 'Doogal (2006)', 'Ian McKellen'] }
    end
    describe 'for a normal match (backup)' do
      subject { OracleOfBacon::Response.new(File.read 'spec/graph_example2.xml') }
      its(:type) { should == :graph }
      its(:data) { should == ["Ian McKellen", "Doogal (2006)", "Kevin Smith (I)",
                              "Fanboys (2009)", "Carrie Fisher"] }
    end
    describe 'for a spellcheck match' do
      subject { OracleOfBacon::Response.new(File.read 'spec/spellcheck_example.xml') }
      its(:type) { should == :spellcheck }
      its(:data) { should have(34).elements }
      its(:data) { should include('Anthony Perkins (I)') }
      its(:data) { should include('Anthony Parkin') }
    end
    describe 'for bad input response' do
      subject { OracleOfBacon::Response.new(File.read 'spec/badinput.xml') }
      its(:type) { should == :badinput }
      its(:data) { should match /No query received/i }
    end
    describe 'for no link response' do
      subject { OracleOfBacon::Response.new(File.read 'spec/unlinkable.xml') }
      its(:type) { should == :unlinkable }
      its(:data) { should match /There is no link/i }
    end
    describe 'for unauthorized access/invalid API key' do
      subject { OracleOfBacon::Response.new(File.read 'spec/unauthorized_access.xml') }
      its(:type) { should == :unauthorized }
      its(:data) { should match /unauthorized/i }
    end
  end
  describe 'constructing URI' do
    subject do
      oob = OracleOfBacon.new('fake_key')
      oob.to = '3%2 "a' ; oob.from = 'George Clooney'
      oob.make_uri_from_arguments
      oob.uri
    end
    it { should match(URI::regexp) }
    it { should match /p=fake_key/ }
    it { should match /b=George\+Clooney/ }
    it { should match /a=3%252\+%22a/ }
  end
  describe 'service connection' do
    before(:each) do
      @oob = OracleOfBacon.new
      allow(@oob).to receive(:valid?).and_return(true)
    end
    it 'should create XML if valid response (also tests badinput and unklinkable cases)' do
      body = File.read 'spec/graph_example.xml'
      FakeWeb.register_uri(:get, %r(http://oracleofbacon\.org), :body => body)
      expect(OracleOfBacon::Response).to receive(:new).with(body)
      @oob.find_connections
    end
    it 'should properly handle status 403 response (Unauthorized access)' do
      body = File.read 'spec/unauthorized_access.xml'
      FakeWeb.register_uri(:get, %r(http://oracleofbacon\.org), 
        :exception =>OpenURI::HTTPError)
      expect(OracleOfBacon::Response).to receive(:new).with(body.chomp)
      @oob.find_connections
    end
    it 'should raise OracleOfBacon::NetworkError if network problem' do
      FakeWeb.register_uri(:get, %r(http://oracleofbacon\.org),
        :exception => Timeout::Error)
      lambda { @oob.find_connections }.
        should raise_error(OracleOfBacon::NetworkError)
    end
  end

end
      
