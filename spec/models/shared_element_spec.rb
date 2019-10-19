require 'rails_helper'

RSpec.describe SharedElement, type: :model do
  it_should_behave_like Element do
    let( :element ) { described_class }
  end
end