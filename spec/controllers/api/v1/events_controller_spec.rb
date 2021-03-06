require 'rails_helper'

describe Api::V1::EventsController, type: :controller do
  include Randomness
  include ResponseJson

  after(:all) do
    Events::GitRepositoryAdd.destroy_all
    Events::GitRepositoryDestroy.destroy_all
    Events::TrialAdd.destroy_all
    Events::TrialTableAdd.destroy_all
    Events::TrialTableRemove.destroy_all
    GitRepository.destroy_all
    Rule.destroy_all
    Trial.destroy_all
    TrialTable.destroy_all
  end
  
  it 'should accept git repository add events' do
    rand_times.map { { url: Faker::Internet.url, name: Faker::Hipster.word } }.each do |vals|
      gr_id = nil
      expect(GitService).to receive(:init) do |id|
        gr_id = id
      end
      
      post(:create, 'events_git_repository_add' => vals)

      em = Events::GitRepositoryAdd.where(url: vals[:url], name: vals[:name]).first

      expect(em).to_not be_nil
      expect(em.git_repository).to_not be_nil
      expect(gr_id).to eql(em.git_repository._id.to_s)
    end
  end

  it 'should accept git repository destroy events' do
    clean_em_id = nil
    expect(GitService).to receive(:clean).at_least(:once) do |id|
      clean_em_id = id
    end
    rand_array_of_models(:git_repository).each do |grm|
      post(:create, 'events_git_repository_destroy' => { git_repository_id: grm.public_id })

      expect(Events::GitRepositoryDestroy.where(git_repository_id: grm.public_id).count).to eql(1)
      em = Events::GitRepositoryDestroy.where(git_repository_id: grm.public_id).first
      expect(em).to_not be_nil
      expect(GitRepository.where(public_id: grm.public_id).first).to be_nil
      expect(clean_em_id).to eql(grm._id.to_s)
    end
  end

  it 'should show git repository add events' do
    expect(GitService).to receive(:init).at_least(:once)
    
    rand_array_of_models(:events_git_repository_add).each do |gram|
      get(:show, id: gram.public_id)
      
      gram.reload
      expect(response).to be_success
      expect(response_json).to eql(encode_decode(EventSerializer.as_json(gram)))
    end
  end

  it 'should accept trial add events' do
    rand_times.each do
      rm = create(:rule)
      ver = Faker::Number.hexadecimal(6)
      
      post(:create, 'events_trial_add' => { rule_id: rm.public_id, version: ver })

      em = Events::TrialAdd.where(rule_id: rm.public_id).last

      expect(em).to_not be_nil
      expect(em.rule_id).to eql(rm.public_id)
      expect(em.version).to eql(ver)
      expect(em.trial).to_not be_nil
      expect(em.trial.label).to_not be_nil
      expect(em.trial.rule).to eql(rm)
    end
  end

  it 'should show trial add events' do
    rm = create(:rule)
    rand_array_of_models(:events_trial_add, rule_id: rm.public_id).each do |tam|
      tm = create(:trial, rule: rm)
      tam.trial = tm

      get(:show, id: tam.public_id)
      
      tam.reload
      expect(response).to be_success
      expect(response_json).to eql(encode_decode(EventSerializer.as_json(tam)))
    end
  end

  it 'should accept trial table add events' do
    rand_times.each do
      rm = create(:rule)
      name = Faker::StarWars.planet
      content = rand_array { rand_document }

      post(:create, 'events_trial_table_add' => { rule_id: rm.public_id, name: name, content: MultiJson.encode(content) })

      em = Events::TrialTableAdd.where(rule_id: rm.public_id).last

      expect(em).to_not be_nil
      expect(em.rule_id).to eql(rm.public_id)
      expect(em.name).to eql(name)
      expect(em.content).to eql(MultiJson.encode(content))

      expect(em.trial_table).to_not be_nil
      expect(em.trial_table.name).to eql(name);
      expect(em.trial_table.content).to eql(content)
      expect(em.trial_table.rule).to eql(rm)
    end
  end

  it 'should show trial table add events' do
    rm = create(:rule)
    rand_array_of_models(:events_trial_table_add, rule_id: rm.public_id).each do |ttam|
      ttm = create(:trial_table, rule: rm)
      ttam.trial_table = ttm

      get(:show, id: ttam.public_id)
      
      ttam.reload
      expect(response).to be_success
      expect(response_json).to eql(encode_decode(EventSerializer.as_json(ttam)))
    end
  end

  it 'should accept trial table destroy events' do
    clean_em_id = nil
    rand_array_of_models(:trial_table).each do |ttm|
      post(:create, 'events_trial_table_remove' => { trial_table_id: ttm.public_id })

      cr = Events::TrialTableRemove.where(trial_table_id: ttm.public_id)
      expect(cr.count).to eql(1)
      em = cr.first
      expect(em).to_not be_nil
      expect(TrialTable.where(public_id: ttm.public_id).first).to be_nil
    end
  end
end
