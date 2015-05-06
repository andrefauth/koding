{argv}      = require 'optimist'
KONFIG      = require('koding-config-manager').load("main.#{argv.c}")
jraphical   = require 'jraphical'
crypto      = require 'crypto'
Bongo       = require "bongo"
Email       = require './email'
KodingError = require '../error'

{ protocol, hostname } = KONFIG
{ secure, signature, dash } = Bongo

module.exports = class JInvitation extends jraphical.Module

  @trait __dirname, '../traits/grouprelated'
  @trait __dirname, '../traits/protected'


  {permit} = require './group/permissionset'

  @share()

  @set
    permissions     :
      'send invitations' : ['moderator', 'admin']
    indexes         :
      code          : 'unique'
      # email         : 'ascending'
      # groupName     : 'ascending'
      #
      # TODO(cihagir) create a compound unique index on groupName and email
    sharedMethods   :

      instance:
        remove:[
          (signature Function)
          (signature Object, Function)
        ]
      static:
        some:[
          (signature Object, Object, Function)
          (signature Object, Object, Object, Function)
        ]
        search:[
          (signature String, Object, Function)
          (signature Object, String, Object, Function)
        ]
        create:
          (signature Object, Function)
        byCode:
          (signature String, Function)
        sendInvitationByCode:[
          (signature String, Function)
          (signature Object, String, Function)
        ]

    sharedEvents    :
      static        : []
      instance      : []
    schema          :
      code          :
        type        : String
        required    : yes
      email         :
        type        : String
        required    : yes
      hash          :
        type        : String
        required    : yes
      firstName     :
        type        : String
      lastName      :
        type        : String
      groupName     :
        type        : String
        required    : yes
      status        :
        type        : String
        enum        : ['invalid status type', [
          'pending',
          'accepted'
        ]]
        default     : 'pending'
      createdAt     :
        type        : Date
        default     : -> new Date

  accept$: secure (client, callback) ->
    { delegate } = client.connection
    @accept delegate, callback

  accept: (account, callback) ->
    operation = $set : { status: 'accepted' }
    @update operation, callback

  # remove deletes an invitation from database
  remove$: permit 'send invitations',
    success: (client, callback) ->
      @remove callback

  # some selects result set for invitations, it adds group name automatically
  @some$: permit 'send invitations',
    success: (client, selector, options, callback) ->
      groupName = client.context.group or 'koding'

      selector or= {}
      selector.groupName = groupName # override group name in any case
      selector.status  or= "pending"

      { limit }       = options
      options.sort  or= createdAt : -1
      options.limit or= 25
      options.limit   = Math.min options.limit, 25 # admin can fetch max 25 record
      options.skip    = 0

      console.log selector, options
      JInvitation.some selector, options, callback

  # search searches database with given query string, adds `starting
  # with regex` around query param
  @search$: permit 'send invitations',
    success: (client, query, options, callback) ->
      return callback new KodingError "query is not set"  if query is ""

      $query = ///^#{query}///
      selector = { $or : [
          { 'name'  : $query }
          { 'email' : $query }
        ]
      }

      JInvitation.some$ client, selector, options, callback

  # create creates JInvitation documents for all given invitations and
  # triggers sendInvitationEmail
  @create: permit 'send invitations',
    success: (client, options, callback) ->
      JUser               = require './user'
      { delegate }        = client.connection
      { invitations }     = options
      groupName           = client.context.group or 'koding'
      name                = getName delegate

      queue = invitations.map (invitation) -> ->
        { email, firstName, lastName } = invitation

        hash = JUser.getHash email
        code = generateInvitationCode email, groupName

        data = {
          code
          email
          groupName
          hash
        }
        # firstName and lastName are optional
        data.firstName = firstName  if firstName
        data.lastName  = lastName  if lastName

        invite = new JInvitation data
        invite.save (err) ->
          return callback err   if err

          JInvitation.sendInvitationEmail client, invite, -> queue.fin()

      dash queue, callback

  # byCode fetches an invitation by its code
  @byCode: (code, callback) ->
    @one {code}, callback

  # sendInvitationByCode sends email according to data stored in
  # JInvitation selected by given code
  @sendInvitationByCode: permit 'send invitations',
    success: (client, code, callback) ->

      JInvitation.byCode code, (err, invitation) ->
        return callback err  if err

        JInvitation.sendInvitationEmail client, invitation, callback

  # sendInvitationEmail sends email according to given JInvitation
  @sendInvitationEmail: (client, invitation, callback) ->
    invitee      = getName client.connection.delegate

    options =
      to      : invitation.email,
      subject : Email.types.INVITE

    properties =
      groupName: invitation.groupName
      invitee  : invitee
      link     : "#{protocol}//#{invitation.groupName}.#{hostname}/Invitation/#{encodeURIComponent invitation.code}"

    Email.queue invitation.email, options, properties, callback


  getName = (delegate) ->
    { nickname, firstName, lastName } = delegate.profile.nickname

    name = nickname

    if "#{firstName}" is not ""
      name = firstName

    if "#{lastName}" is not ""
      name = "#{name} #{lastName}"

    return name

  # TODO - generate a better invitation code
  generateInvitationCode = (email, group) ->
    code = crypto.createHmac 'sha1', 'kodingsecret'
    code.update email
    code.update group
    code.digest 'hex'
