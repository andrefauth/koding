class AccountPaymentHistoryListController extends KDListViewController

  constructor:(options,data)->
    super options,data

    @list = @getListView()
    @list.on "Reload", (uuid)=>
      @loadItems()

    @loadItems()

  loadItems:->
    @removeAllItems()
    @showLazyLoader no

    transactions = []
    KD.remote.api.JRecurlyPlan.getUserTransactions (err, trans) =>
      if err
        @instantiateListItems []
        @hideLazyLoader()
      unless err
        for t in trans
          if t.amount + t.tax is 0
            continue
          transactions.push
            status     : t.status
            amount     : ((t.amount + t.tax) / 100).toFixed(2)
            currency   : 'USD'
            createdAt  : t.datetime
            paidVia    : if t.card then t.card else ""
            owner      : t.owner
            refundable : t.refundable
        @instantiateListItems transactions
        @hideLazyLoader()

  loadView:->
    super
    @getView().parent.addSubView reloadButton = new KDButtonView
      style     : "clean-gray account-header-button"
      title     : ""
      icon      : yes
      iconOnly  : yes
      iconClass : "refresh"
      callback  : =>
        @getListView().emit "Reload"

class AccountPaymentHistoryList extends KDListView

  constructor:(options,data)->
    options = $.extend
      tagName      : "ul"
      itemClass : AccountPaymentHistoryListItem
    ,options
    super options,data

class AccountPaymentHistoryListItem extends KDListItemView
  constructor:(options,data)->
    options = tagName : "li"
    super options,data

  viewAppended:->
    super
    @addSubView editLink = new KDCustomHTMLView
      tagName      : "a"
      partial      : "View invoice"
      cssClass     : "action-link"

  click:(event)->
    if $(event.target).is "a.delete-icon"
      @getDelegate().emit "UnlinkAccount", accountType : @getData().type

  partial:(data)->
    """
      <span class='darkText'>#{data.title}</span>
    """
    cycleNotice = if data.billingCycle then "/#{data.billingCycle}" else ""
    """
      <div class='labelish'>
        <span class='invoice-date'>#{data.createdAt}</span>
      </div>
      <div class='swappableish swappable-wrapper posstatic'>
        <span class='ttag #{data.status}'>#{data.status.toUpperCase()}</span>
        <strong>$#{data.amount}</strong>
        <cite>#{data.paidVia}</cite>
      </div>
    """