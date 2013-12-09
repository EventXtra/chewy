require 'spec_helper'

describe Chewy::Type::Import do
  include ClassHelpers

  before do
    stub_model(:city)
  end

  let(:cities) do
    index_class(:cities) do
      define_type do
        envelops City
        field :name
      end
    end
  end

  let!(:dummy_cities) { 3.times.map { |i| City.create(name: "name#{i}") } }
  let(:city) { cities.city }

  describe '.import' do
    specify { expect { city.import([]) }.not_to update_index(city) }
    specify { expect { city.import }.to update_index(city).and_reindex(dummy_cities) }
    specify { expect { city.import dummy_cities }.to update_index(city).and_reindex(dummy_cities) }
    specify { expect { city.import dummy_cities.map(&:id) }.to update_index(city).and_reindex(dummy_cities) }
    specify { expect { city.import(City.where(name: ['name0', 'name1'])) }
      .to update_index(city).and_reindex(dummy_cities.first(2)) }
    specify { expect { city.import(City.where(name: ['name0', 'name1']).map(&:id)) }
        .to update_index(city).and_reindex(dummy_cities.first(2)) }

    specify do
      dummy_cities.first.destroy
      expect { city.import dummy_cities }
        .to update_index(city).and_reindex(dummy_cities.from(1)).and_delete(dummy_cities.first)
    end

    specify do
      dummy_cities.first.destroy
      expect { city.import dummy_cities.map(&:id) }
        .to update_index(city).and_reindex(dummy_cities.from(1)).and_delete(dummy_cities.first)
    end

    specify do
      dummy_cities.first.destroy
      expect(cities.client).to receive(:bulk).with(hash_including(
        body: [{delete: {_index: 'cities', _type: 'city', _id: dummy_cities.first.id}}]
      ))
      dummy_cities.from(1).each.with_index do |c, i|
        expect(cities.client).to receive(:bulk).with(hash_including(
          body: [{index: {_id: c.id, _index: 'cities', _type: 'city', data: {'name' => "name#{i+1}"}}}]
        ))
      end
      city.import dummy_cities.map(&:id), batch_size: 1
    end

    context 'scoped' do
      let(:cities) do
        index_class(:cities) do
          define_type do
            envelops City do
              where(name: ['name0', 'name1'])
            end
            field :name
          end
        end
      end

      specify { expect { city.import }.to update_index(city).and_reindex(dummy_cities.first(2)) }
    end
  end
end