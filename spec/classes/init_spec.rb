require 'spec_helper'
describe 'monitoring' do

  context 'with defaults for all parameters' do
    it { should contain_class('monitoring') }
  end
end
