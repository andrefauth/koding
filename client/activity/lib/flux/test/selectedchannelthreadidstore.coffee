{ expect } = require 'chai'

Reactor = require 'app/flux/reactor'

SelectedChannelThreadIdStore = require '../stores/selectedchannelthreadidstore'
actionTypes = require '../actions/actiontypes'

describe 'SelectedChannelThreadIdStore', ->

  beforeEach ->
    @reactor = new Reactor
    @reactor.registerStores selectedThreadId: SelectedChannelThreadIdStore

  describe '#setSelectedChannelId', ->

    it 'sets selected thread id to given channel id', ->

      @reactor.dispatch actionTypes.SET_SELECTED_CHANNEL_THREAD, channelId: '1'
      selectedId = @reactor.evaluate ['selectedThreadId']

      expect(selectedId).to.equal '1'

      @reactor.dispatch actionTypes.SET_SELECTED_CHANNEL_THREAD, channelId: '2'
      selectedId = @reactor.evaluate ['selectedThreadId']

      expect(selectedId).to.equal '2'


