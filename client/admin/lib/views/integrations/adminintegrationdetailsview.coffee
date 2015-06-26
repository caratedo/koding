kd                   = require 'kd'
JView                = require 'app/jview'
globals              = require 'globals'
showError            = require 'app/util/showError'
KDInputView          = kd.InputView
KDLabelView          = kd.LabelView
KDButtonView         = kd.ButtonView
applyMarkdown        = require 'app/util/applyMarkdown'
CustomLinkView       = require 'app/customlinkview'
KDCustomHTMLView     = kd.CustomHTMLView
KDFormViewWithFields = kd.FormViewWithFields


module.exports = class AdminIntegrationDetailsView extends JView

  constructor: (options = {}, data) ->

    options.cssClass = 'integration-details'

    super options, data

    { instructions } = data
    @eventCheckboxes = {}

    # DUMMY DATA
    data.settings =
      events: [
        { name: 'added_feature',  description: 'Added feature'  }
        { name: 'added_comment',  description: 'Added comment'  }
        { name: 'edited_feature', description: 'Edited feature' }
        { name: 'moved_feature',  description: 'Moved feature'  }
      ]

    if instructions
      @instructionsView = new KDCustomHTMLView
        tagName  : 'section'
        cssClass : 'has-markdown instructions'
        partial  : """
          <h4 class='title'>Setup Instructions</h4>
          <p class='subtitle'>Here are the steps necessary to add the #{data.title} integration.</p>
          <hr />
        """
      @instructionsView.addSubView new KDCustomHTMLView
        partial  : applyMarkdown instructions
    else
      @instructionsView = new KDCustomHTMLView cssClass: 'hidden'

    channels = ({ title: channel.name, value: channel.id } for channel in data.channels)

    formOptions         =
      cssClass          : 'AppModal-form details-form'
      callback          : @bound 'handleFormCallback'
      fields            :
        channels        :
          type          : 'select'
          label         : '<p>Post to Channel</p><span>Which channel should we post exceptions to?</span>'
          selectOptions : channels
          defaultValue  : data.selectedChannel
        url             :
          label         : "<p>Webhook URL</p><span>When setting up this integration, this is the URL that you will paste into #{data.title}.</span>"
          defaultValue  : data.webhookUrl
          attributes    : readonly: 'readonly'
          nextElement   :
            regenerate  :
              itemClass : CustomLinkView
              title     : 'Regenerate'
              cssClass  : 'link'
              click     : @bound 'regenerateToken'
        label           :
          label         : '<p>Descriptive Label</p><span>Use this label to provide extra context in your list of integrations (optional).</span>'
          defaultValue  : data.summary
        name            :
          label         : '<p>Customize Name</p><span>Choose the username that this integration will post as.</span>'
          defaultValue  : data.title
        events          :
          label         : '<p>Customize Events</p><span>Choose the events you would like to receive events for.</span>'
          type          : 'hidden'
          cssClass      : unless data.settings?.events?.length then 'hidden'
      buttons           :
        Save            :
          title         : 'Save Integration'
          type          : 'submit'
          cssClass      : 'solid green medium save'
          loader        : yes
        Cancel          :
          title         : 'Cancel'
          cssClass      : 'solid green medium red'
          callback      : => @emit 'IntegrationCancelled'

    { integrationType, isDisabled } = @getData()

    if integrationType is 'configured'
      cssClass = 'disable status'
      title    = 'Disable Integration'

      if isDisabled
        cssClass = 'enable status'
        title    = 'Enable Integration'

      formOptions.fields.status =
        label     : '<p>Integration Status</p><span>You can enable/disable your integration here.</span>'
        itemClass : KDCustomHTMLView
        partial   : title
        cssClass  : cssClass
        click     : @bound 'handleStatusChange'

    @settingsForm = new KDFormViewWithFields formOptions

    @createEventCheckboxes()


  createEventCheckboxes: ->

    selectedEvents = {}

    for event in @getData().selectedEvents
      selectedEvents[event.name] = event

    mainWrapper = new KDCustomHTMLView cssClass: 'event-cbes'

    for item in @data.settings?.events

      wrapper = new KDCustomHTMLView cssClass: 'event-cb'

      label   = new KDLabelView
        title : item.description

      wrapper.addSubView new KDInputView
        type         : 'checkbox'
        name         : item.name
        label        : label
        defaultValue : if selectedEvents[item.name] then yes else ''

      wrapper.addSubView label
      mainWrapper.addSubView wrapper

    @settingsForm.fields.events.addSubView mainWrapper


  handleFormCallback: (formData) ->

    data = @getData()
    { name, label, channels } = formData
    options       =
      id          : data.id
      channelId   : channels

    if label isnt data.summary
      options.description = label

    if name isnt data.title
      options.settings = customName : name

    kd.singletons.socialapi.integrations.update options, (err) =>
      return kd.warn err  if err

      @settingsForm.buttons.Save.hideLoader()
      @emit 'NewIntegrationSaved'


  regenerateToken: ->

    return  if @regenerateLock

    @regenerateLock = yes
    { id, name }    = @getData()

    kd.singletons.socialapi.integrations.regenerateToken { id }, (err, res) =>
      return showError  if err

      { url, Regenerate } = @settingsForm.inputs

      url.setValue "#{globals.config.integration.url}/#{name}/#{res.token}"

      Regenerate.updatePartial 'Webhook url has been updated!'
      Regenerate.setClass 'label'

      kd.utils.wait 4000, =>
        Regenerate.updatePartial 'Regenerate'
        Regenerate.unsetClass 'label'
        @regenerateLock = no


  handleStatusChange: ->

    { id, selectedChannel, isDisabled } = @getData()
    newState     = not isDisabled
    data         =
      id         : id
      channelId  : selectedChannel
      isDisabled : newState

    kd.singletons.socialapi.integrations.update data, (err, res) =>

      return showError  if err

      @getData().isDisabled = newState
      { status } = @settingsForm.inputs

      if newState # this means disabled
        status.setClass      'enable'
        status.unsetClass    'disable'
        status.updatePartial 'Enable Integration'
      else
        status.setClass      'disable'
        status.unsetClass    'enable'
        status.updatePartial 'Disable Integration'


  pistachio: ->

    { title, description, summary, iconPath } = @getData()

    return """
      <header class="integration-view">
        <img src="#{iconPath}" />
        {p{ #(title)}}
        {{ #(summary)}}
      </header>
      {section.description{ #(description)}}
      {{> @instructionsView}}
      <section class="settings">
        <h4 class='title'>Integration Settings</h4>
        <hr />
        {{> @settingsForm}}
      </section>
    """
