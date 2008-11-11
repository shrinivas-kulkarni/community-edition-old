<%
	String overlayPath = org.alfresco.web.studio.OverlayUtil.getOriginalURL(request, "/proxy/alfresco-web-studio/overlay/default");
	String iconsPath = overlayPath + "/images/icons";
%>

if (typeof WebStudio == "undefined")
{
	var WebStudio = {};
}

/**
 * Constructs a new Alfresco Application instance.
 *
 * There should only be one Alfresco Application instance active in
 * the browser at a time.
 *
 * @return Alfresco application instance
 */
WebStudio.Application = function() 
{
	if (typeof WebStudio.app != "undefined") 
	{
		this.addDebugMessages('error', 'WebStudio.app already exist')
		return null;
	}

	WebStudio.app = this;

	this.defaultContainer = $('templateContainer');
	this.defaultTemplateSelector = 'div[id=AlfrescoApplicationTemplate]';

	this.defaultElementsConfig = {
	
		StartEditControl: {
	
			selector: 'div[id=AAStartEditControl]',
			blockSelection: true,
			objects: {
				ContentManagedIcon: {
					selector: '.AAContentManagedIcon'
					,
					events: {
						click: function() {
							WebStudio.app.toggleEdit();
						}
					}
				}
				,
				ContentEditIcon: {
					selector: '.AAContentEditIcon'
					,
					events: {
						click: function() {
							WebStudio.app.toggleEdit();
						}
					}
				}
				,
				ContentEditCaption: {
					selector: '.AAContentEditCaption'
					,
					events: {
						click: function() {
							WebStudio.app.toggleEdit();
						}
					}
				}
			}
		}
		,
		PanelsHolder: {
			selector: 'div[id=AATwoPanels]'
		}
		,
		FormTemplate: {
			selector: 'div[id=AlfrescoForm]'
			,
			remove: true
		}
		,
		AlfrescoMessageBoxTmplate: {
			selector: 'div[id=AlfrescoMessageBoxTmplate]'
			,
			remove: true
		}
		,
		AlfrescoMessageBoxProgressBar: {
			selector: 'div[id=AlfrescoMessageBoxProgressBar]'
			,
			remove: true
		}
    }

	this.editState = 'view'; //'view' or 'edit'
    this.isHideDockingPanel = false;

	// menu
	this.activeMenu = null;
	this.pageEditor = null;
	this.contentEditor = null;
	
	this.applications = { };
}

WebStudio.Application.prototype = new WebStudio.AbstractTemplater('WebStudio.Application');

/**
 * Loads application resources for the Alfresco application.
 */
WebStudio.Application.prototype.init = function() 
{
	this.activate();
	this.resizeWindow();
}

/**
 * Called after resource loading is completed.
 *
 * This initializes the Alfresco application.
 */
WebStudio.Application.prototype.activate = function() 
{
	// builds all dom elements for the container
	this.buildGeneralLayer();

	// moves all body elements into the body container
	WebStudio.bodyContainer.getChildren().injectInside(WebStudio.app.panels.secondPanel);
	
	var a = WebStudio.app.panels.secondPanel;
	a.setStyle("overflow", "auto");
	
	// tells the application to listen "resize" events of the window
	window.addEvent('resize', function() 
	{
		WebStudio.app.resize();
	});

	// updates the floating menu position
	this.updateFloatingMenuPosition();

	// initializes the application overlays
	this.showFloatingMenu();
};

/**
 * Builds the application and applets
 */
WebStudio.Application.prototype.build = function() 
{
	var _this = this;
	
	this.generalLayer.set({
		id: 'AlfrescoApplication'
	});

	this.panels = new WebStudio.Splitter('AlfrescoAppGeneralPanel');
	this.panels.onPanelsResize = function(fs,sz)
	{
		_this.onPanelsResize(fs,sz);
	}
	with (this.PanelsHolder.el.style) {
        top = "0px";
        left = "0px";
    }
    
    this.panels.injectObject = this.PanelsHolder.el;
	this.panels.activate();
	
	// hide the panels
	if(this.panels)
	{
		this.panels.hidePanel(true);
	}	
	
	// hide the menu
	if(this.activeMenu)
	{
		this.activeMenu.hide();
	}
}




















///////////////////////////////////////////////////////////////////
//
// Embedded Applications
//
///////////////////////////////////////////////////////////////////

WebStudio.Application.prototype.getApplications = function()
{
	return this.applications;
}

WebStudio.Application.prototype.getApplication = function(id)
{
	return this.getApplications()[id];
}

WebStudio.Application.prototype.getDefaultApplication = function()
{
	return this.getApplication(this.getDefaultApplicationId());
}

WebStudio.Application.prototype.getDefaultApplicationId = function()
{
	if(!this.defaultApplicationId)
	{
		for(var appId in this.applications)
		{
			this.defaultApplicationId = appId;
			return this.defaultApplicationId;
		}
	}
	return this.defaultApplicationId;
}

WebStudio.Application.prototype.setDefaultApplicationId = function(defaultApplicationId)
{
	this.defaultApplicationId = defaultApplicationId;
}

WebStudio.Application.prototype.selectApplication = function(appId) 
{
	if(appId == "off" || appId == null)
	{
		this.endEdit();
		this.currentApplicationId = null;
		return;	
	}
	
	if(this.currentApplicationId != null && this.currentApplicationId == appId)
	{
		// we're already viewing this application, so skip
		return;
	}
	
	// if there is a current application, hide and remove its old stuff
	if(this.currentApplicationId)
	{
		this.hideSlidersPanel();
		this.activeMenu.hide();
		
		// move old panel to application panel holding space
		$('ApplicationSplitterPanelHolder').appendChild(this.panels.firstPanel);
	}
	
	// Get the application we seek
	var application = this.applications[appId];
	if(application == null)
	{
		alert('no such application');
		return;
	}
	
	// Flip on the application
	this.slidersSector = application.slidersSector;
	this.activeMenu = application.getMenu();
	this.activeMenu.show();
	this.currentApplicationId = appId;

	// move our panel into the splitter
	this.panels.firstPanel = application["firstPanel"];
	$('AlfSplitterContainer').appendChild(this.panels.firstPanel);

	// format panels	
	this.panels.minLeftWidth = 230;
	this.panels.minRightWidth = 400;
	this.panels.setPanelsSize(230);
	this.panels.firstPanelSize = this.panels.firstPanel.offsetWidth;
	
	// Resize the panel	
	this.resizePanel();		
		
	// Show the panels
	this.showSlidersPanel();
	
	// Resize the panel	
	this.resizePanel();	
}	

WebStudio.Application.prototype.newMountSelectorItem = function(id, title, imageUrl, selected)
{
	var _this = this;
	
	var mountSelectorRoot = new Element('div', { 
		'class': 'MountSelectorRoot', 
		'styles': { width: '70px' }
	});
	
	var table = new Element('table', {
		'height': '21px',
		'width': '100%',
		'cellpadding': '0',
		'cellspacing': '0',
		'border': '0'
	});
	mountSelectorRoot.adopt(table);
	
	// ROW
	var tr = new Element('tr');
	table.adopt(tr);
	
	// TD SPACER
	var td1 = new Element('td', {
		'width': '3px',
		'class': 'MountSelectorLeft',
		'html': '&nbsp;'
	});
	tr.adopt(td1);
	
	// TD IMAGE
	var td2 = new Element('td', {
		'class': 'MountSelectorCenter',
		'valign': 'middle',
		'events': {
			'click' : function() {
				_this.onMountSelectorClick(id);
			}
		}		
	});
	tr.adopt(td2);	
	var img = new Element('img', {
		'src': imageUrl
	});
	td2.adopt(img);
	
	// TD TITLE
	var td3class = "MountSelectorCenter";
	if(selected)
	{
		td3class = "MountSelectorCenterSelected";
	}
	var td3 = new Element('td', {
		'id': 'mountSelectorItem_' + id,
		'class': td3class,
		'events': {
			'click' : function() {
				_this.onMountSelectorClick(id);
			}
		}
	});
	td3.setHTML(title);
	tr.adopt(td3);
	
	// TD SPACER
	var td4 = new Element('td', {
		'width': '3px',
		'class': 'MountSelectorRight',
		'html': '&nbsp;'
	});
	tr.adopt(td4);
	
	return mountSelectorRoot;
}
















WebStudio.Application.prototype.setElementConfig = function(item, index, ob, config, oel)
{
	//'item' = html dom element, 'index' = name of array of 'item's; ob = js container for 'index'; config = js object with configuration for item
	if (config.setNumber) {
		var p = {};
		p[config.setNumber] = index;
		o.el.set(p);
	}

	if (config.dragHandler)
	if (this[config.dragObject]) {
		new Drag.Move(this[config.dragObject].el, {handle: oel});
	}
}

/**
 * Checks whether the user is authenticated to Web Studio and, if not,
 * redirects them to the login page.
 */
WebStudio.Application.prototype.userAuth = function()
{
	var userAuth = WebStudio.context.isAuthenticated();
	
	// ensure the user is authenticated
	if(!userAuth)
	{
		// show the login control
		this.loginDialog = new WebStudio.LoginDialog();
		
		// set up login handler
		this.loginDialog.setLoginHandler(this.loginHandler.bind(this));
		
		// activate and pop up
		this.loginDialog.activate();
		this.loginDialog.popup();
	}
	
	return userAuth;
}

WebStudio.Application.prototype.loginHandler = function(e)
{
	// call over to login web script
	var url = WebStudio.ws.studio("/api/login", { "u" : this.loginDialog.Username.el.value, "pw" : this.loginDialog.Password.el.value } );
	this.call = YAHOO.util.Connect.asyncRequest('GET', url, {	
		success: (function(r) {
		
			var responseText = r.responseText;
			if("AUTHENTICATED" == responseText)
			{
				// they successfully authenticated to web studio
				this.loginDialog.popout();
				
				// mark that the user signed in
				WebStudio.context.username = this.loginDialog.Username.el.value;
				
				// re-init the floating menu
				this.showFloatingMenu();
			}
		
		}).bind(this)
		,
		failure: (function(r) {
		
			// TODO: display some kind of message?
			
		}).bind(this)
	});		
}

WebStudio.Application.prototype.sandboxMounted = function()
{
	var sandboxMounted = WebStudio.context.isSandboxMounted();
	
	// ensure the user sandbox is mounted
	if(!sandboxMounted)
	{
		// show the sandbox dialog
		this.sandboxDialog = new WebStudio.SandboxDialog();
		
		// set up the sandbox dialog handlers
		this.sandboxDialog.setWebSiteCreateHandler(this.webSiteCreateHandler.bind(this)); 
		this.sandboxDialog.setWebSiteLoadHandler(this.webSiteLoadHandler.bind(this));
		
		// activate and pop up
		this.sandboxDialog.activate();
		this.sandboxDialog.popup();
	
	}
	
	return sandboxMounted;	
}

WebStudio.Application.prototype.webSiteCreateHandler = function(e)
{
	var webSiteName = this.sandboxDialog.ToolCreateWebSiteName.el.value;
	var webSiteBasedOn = this.sandboxDialog.ToolCreateWebSiteBasedOn.el.value;
	var webSiteDescription = webSiteName;
	
	// TODO: figure a nice, easy DNS name for this web project
	// We use some voodoo assumptions here...
	var webSiteId = webSiteName.split(' ').join('');
	
	if(webSiteName && webSiteBasedOn && webSiteId)
	{
		// call web studio to tell it to create the web project
		var url = WebStudio.ws.studio("/api/site/create", { id: webSiteId, name: webSiteName, description: webSiteDescription, basedOn: webSiteBasedOn } );
		var callback = {
		
			success: (function(oResponse) {
				
				var data = Json.evaluate(oResponse.responseText);
					
				// set up the context
				WebStudio.context.webProjectId = webSiteId;
				WebStudio.context.sandboxId = webSiteId;
				WebStudio.context.storeId = webSiteId;
				
				// do another call to set the context
				//this.setContext(WebStudio.context.webProjectId, WebStudio.context.sandboxId, WebStudio.context.storeId);
									
				// refresh the page
				this.refreshBrowser();
	
			}).bind(this)
			,
			failure: function(oResponse) {
			
				// TODO
			}
			,
			timeout: 10000
		};
		YAHOO.util.Connect.asyncRequest('GET', url, callback);
	}
}

WebStudio.Application.prototype.webSiteLoadHandler = function(e)
{
	// selected project id
	var selectedWebSiteId = this.sandboxDialog.ToolLoadWebSiteSelectedId.el.value;	
	if(selectedWebSiteId != null)
	{
		// call over and fetch metadata about this web project
		// we must determine it's web project id, its staging sandbox id and its store id

		var webProjectRef = selectedWebSiteId; // dns name
		var url = WebStudio.ws.repo("/api/wcm/webproject/" + webProjectRef);
	
		var callback = {
	
			success: (function(oResponse) {
				
				var data = Json.evaluate(oResponse.responseText);
				var webProjectId = data.webprojectref;
								
				// TODO: look up sandboxes, here we assume the staging store name
				
				var sandboxId = data.webprojectref
				var storeId = data.webprojectref
				
				var _onComplete = (function() {

					// activate and pop up
					this.sandboxDialog.popout();
					
					// callback once cache finishes refreshing
					var fCallback = (function()
					{
						// refresh the page
						this.refreshBrowser();
						
					}).bind(this);
					
					// refresh all caches
					this.refreshAll(fCallback);
				}).bind(this);
				
				var _onFailure = (function() {
				
					this.sandboxDialog.popout();
					
					// TODO
					
				}).bind(this);

				// do another call to set the context
				this.setContext(webProjectId, sandboxId, storeId, _onComplete, _onFailure);

			}).bind(this)
			,
			failure: function(oResponse) {
		
				// TODO
			}
			,
			timeout: 7000
		};
		YAHOO.util.Connect.asyncRequest('GET', url, callback);
	}	
}

WebStudio.Application.prototype.setContext = function(webProjectId, sandboxId, storeId, onComplete, onFailure)
{
	var url = WebStudio.ws.studio("/api/context/set", { webProjectId : webProjectId, sandboxId : sandboxId, storeId : storeId } );

	var callback = {
	
		success: (function(oResponse) {
				
			// set up the context
			WebStudio.context.webProjectId = webProjectId;
			WebStudio.context.sandboxId = sandboxId;
			WebStudio.context.storeId = storeId;				
			
			if(onComplete)
			{
				onComplete();
			}

		}).bind(this)
		,
		failure: function(oResponse) {
		
			if(onFailure)
			{
				onFailure();
			}
			else
			{
				alert('set context fail: ' + oResponse.responseText);
			}
		}
		,
		timeout: 7000
	};
	YAHOO.util.Connect.asyncRequest('GET', url, callback);
}

WebStudio.Application.prototype.resetContext = function(callback)
{
	var url = WebStudio.ws.studio("/api/context/set", { webProjectId : "", sandboxId : "", storeId : "" } );
	YAHOO.util.Connect.asyncRequest('GET', url, callback);
}


WebStudio.Application.prototype.loadPage = function(pageId)
{
	/*
	var url = WebStudio.url.studio("/page", { p : pageId } );
	var callback = {
	
		success: (function(oResponse) {
		
			//alert(oResponse.responseText);

		}).bind(this)
		,
		failure: function(oResponse) {
		
			// TODO
		}
		,
		timeout: 7000
	};
	YAHOO.util.Connect.asyncRequest('GET', url, callback);
	*/
	
	window.location.href = "/studio/page?p=" + pageId;
}

WebStudio.Application.prototype.toNodeString = function(nodeRef)
{
	var nodeString = "";
	
	var i = nodeRef.indexOf(":");
	nodeString += nodeRef.substring(0,i);
	nodeString += "/";
	
	var cdr = nodeRef.substring(i+3);
	var i2 = cdr.indexOf("/");
	nodeString += cdr.substring(0, i2);
	nodeString += "/";
	nodeString += cdr.substring(i2+1); 
	
	return nodeString;
}

WebStudio.Application.prototype.getTopOffset = function() 
{
   return 20;
}
















WebStudio.Application.prototype.startApplications = function(postFunction)
{
	// notify the user with a blocked wait that we're loading apps
	this.blockNotify("Loading Applications...");
	
	// bootstrap all of the applications
	this.bootstrapApplications({

		onSuccess: (function() {
		
			this.mountApplications({
			
				onSuccess: (function() {

					this.clearBlockNotify();
										
					// we've mounted the applications
					// select the default application
					this.selectApplication(this.getDefaultApplicationId());
					
					// start the editor
					if(!postFunction)
					{
						this.startEdit();
					}
					else
					{
						postFunction();
					}
					
				}).bind(this)
				,
				onFailure: (function() {

					this.clearBlockNotify();				
					alert("mount applications failed");
					
				}).bind(this)
				
			});
		
		}).bind(this)
		,
		onFailure: (function() {
		
			this.clearBlockNotify();
			alert("Failed to start Applications - bootstrap called failed");
		
		}).bind(this)
		
	});
}

/**
 * Loads and initializes the applications
 * options - object with methods "onSuccess" and "onFailure"
 */
WebStudio.Application.prototype.bootstrapApplications = function(options)
{
	var config = this.applicationsConfig;
	
	var bootstrap = new WebStudio.Bootstrap(config, this.applications);
	bootstrap.onSuccess = (function() 
	{	
		// copy in applets config
		for(var id in config)
		{
			var obj = this.applications[id];
			obj.appletsConfig = WebStudio.app.applicationsConfig[id].applets;			
		}
		
		// mark success
		this.applicationsBootstrapped = true;
		
		if(options.onSuccess)
		{
			options.onSuccess.bind(this).attempt();
		}	
					
	}).bind(this);
	bootstrap.onFailure = (function() 
	{	
		this.applicationsBootstrapped = false;
		
		if(options.onFailure)
		{
			options.onFailure.bind(this).attempt();
		}	
		else
		{
			alert('failed to bootstrap');
		}	
						
	}).bind(this);
	bootstrap.load();
}

WebStudio.Application.prototype.mountApplications = function(options)
{
	for(var id in this.applications)
	{
		// update notification to the end user
		this.blockNotify("Mounting Application: " + this.applications[id].title);

		this.mountApplication(id);
	}
	
	// set up a timed check for completion
	var totalWaitTime = 180000; // 180 seconds
	var checkPeriod = 500; // check every half second
	this.maxMountCheckCount = totalWaitTime / checkPeriod;
	this.mountCheckCount = 0;
	this.mountCheckerOptions = options;				
	this.mountChecker = this.mountCheck.periodical(checkPeriod, this);		
}

WebStudio.Application.prototype.mountCheck = function()
{
	this.mountCheckCount++;
	
	// check to see if all of the objects have finished bootstrapping
	var check = true;
	for(var id in this.applications)
	{
		var app = this.applications[id];
		if(!app.isMounted)
		{
			check = false;
		}
	}			
	if(check)
	{
		$clear(this.mountChecker);
		if(this.mountCheckerOptions.onSuccess)
		{
			this.mountCheckerOptions.onSuccess.bind(this).attempt();
		}
		return true;				
	}
	if (this.mountCheckCount > this.maxMountCheckCount) 
	{
		$clear(this.mountChecker);
		if(this.mountCheckerOptions.onFailure)
		{
			this.mountCheckerOptions.onFailure.bind(this).attempt();
		}				
		return false;
	};	
}
	

WebStudio.Application.prototype.mountApplication = function(appId)
{
	var app = this.applications[appId];
	if(app)
	{
		// store the application config onto the app
		app.config = WebStudio.app.applicationsConfig[appId];
		app.appletsConfig = app.config["applets"];
		
		// configure the application's slider
		var slidersPanelDomId = app.getSlidersPanelDomId();
		var panel = $(slidersPanelDomId);
		app.firstPanel = panel;
		
		// configure the application's "mount selector" (or app selector)
		var mountSelector = new Element('div', { 
			'class': 'MountSelector' 
		});
		mountSelector.injectInside(panel);
		
		// walk through all applications and inject onto app selector
		for(var zId in this.applications)
		{
			var zApp = this.applications[zId];
			var zAppTitle = app.getTabTitle();
			var zAppImageUrl = app.getTabImageUrl();
			
			var zSelected = false;
			
			if(zId == appId) { 
				zSelected = true; 
			}
			 
			var zApplication = this.newMountSelectorItem(zId, zAppTitle, '<%=overlayPath%>' + zAppImageUrl, zSelected);
			zApplication.injectInside(mountSelector);
		}
		
		// build the body of the application slider
		app.slidersSector = new WebStudio.SlidersSector('AlfrescoAppGeneralSlidersSector_' + appId);
		app.slidersSector.defaultTemplateSelector = 'div[id=' + app.getSlidersSectorTemplateId() + ']'
		app.slidersSector.injectObject = app.firstPanel;
		app.slidersSector.activate();
		
		// mark as mounted
		app.isMounted = true;		
	}
}










/**
 *
 * Event Handlers
 *
 */
 
/**
 * Fired when the panels are resized (via the divider)
 */
WebStudio.Application.prototype.onPanelsResize = function(fs,sz)
{
	// tell the page editor to resize all of its colored region overlays
	if(this.pageEditor)
	{
		this.pageEditor.resizeTabItems();
	}
	
	if(this.templateDesigner)
	{
		this.templateDesigner.resize();
	}
}

/*
 * Fired when an application mount selector is clicked
 */
WebStudio.Application.prototype.onMountSelectorClick = function(id)
{
	this.selectApplication(id);
	return this;
}


/**
 * Common error handler for AJAX processes.
 * @param data {object} the server response.
 */
WebStudio.Application.prototype.onFailure = function(data)
{
	alert("Status: " + data.status + "\n" + "Status text: " + data.statusText);
}



 
 
 
 
 
 
 
 




/**
 *
 * General Action Handlers
 *
 * These methods can either be called directly or they are used
 * by other parts of the application to orchestrate things
 *
 */
 
WebStudio.Application.prototype.refreshAll = function(onComplete, onFailure)
{
	var config = { };
	config.webscripts = true;
	config.objects = true;
	
	if(onComplete)
	{
		config.onComplete = onComplete.bind(this);
	}
	
	if(onFailure)
	{
		config.onFailure = onFailure.bind(this);
	}
	
	this.refresh(config);
}

WebStudio.Application.prototype.refreshObjectCache = function(onComplete, onFailure)
{
	var config = { };
	config.webscripts = false;
	config.objects = true;
	config.silent = true;
	
	if(onComplete)
	{
		config.onComplete = onComplete;
	}
	
	if(onFailure)
	{
		config.onFailure = onFailure;
	}
	
	this.refresh(config);
}

WebStudio.Application.prototype.refreshWebScripts = function(onComplete, onFailure)
{
	var config = { };
	config.webscripts = true;
	config.objects = false;
	
	if(onComplete)
	{
		config.onComplete = onComplete;
	}
	
	if(onFailure)
	{
		config.onFailure = onFailure;
	}
	
	this.refresh(config);
}

WebStudio.Application.prototype.refresh = function(options)
{
	var webscripts = options.webscripts;
	var objects = options.objects;
		
	// deep copy object
	var newOptions = { };
	newOptions.webscripts = options.webscripts;
	newOptions.objects = options.objects;
	newOptions.onComplete = options.onComplete;
	newOptions.onFailure = options.onFailure;

	// redirect back to this method
	var myOnComplete = this.refresh.bind(this);
	
	var myOnFailure = (function()
	{
		// unblock
		this.clearBlockNotify();
		
		if(options.onFailure)
		{
			options.onFailure();
		}
		
	}).bind(this);

	if(webscripts)
	{
		if(!options.silent)
		{
			this.blockNotify("Refreshing Web Scripts...");
		}
		
		newOptions.webscripts = null;
		
		this._refreshWebScripts(newOptions, myOnComplete, myOnFailure);
	}
	else if(objects)
	{
		if(!options.silent)
		{
			this.blockNotify("Refreshing Object Cache...");
		}
		
		newOptions.objects = null;
		
		this._refreshObjects(newOptions, myOnComplete, myOnFailure);
	}
	else {

		// otherwise, we have completed
		this.clearBlockNotify();
		
		if(options.onComplete)
		{
			options.onComplete();
		}
	}
}

WebStudio.Application.prototype._refreshWebScripts = function(options, onComplete, onFailure)
{
	var time = new Date();
	
	var url = WebStudio.url.studio("/control/webscripts/reset", { '_dc' : time.getTime() } );
	var ajax = new Ajax(url, 
	{
		method: 'get', 
		onComplete: (function(data)
		{
			onComplete(options);
		}).bind(this)
		,
		onFailure: (function() 
		{
			onFailure(options);
		}).bind(this)
	}).request();	
}

WebStudio.Application.prototype._refreshObjects = function(options, onComplete, onFailure)
{
	var time = new Date();
	
	var url = WebStudio.url.studio("/control/cache/invalidate", { '_dc' : time.getTime() } );
	var ajax = new Ajax(url, 
	{
		method: 'get', 
		onComplete: (function(data)
		{
			onComplete(options);
		}).bind(this)
		,
		onFailure: (function() 
		{
			onFailure(options);
		}).bind(this)
	}).request();
}





/**
 * Repositions the Alfresco Content Edit floating menu
 */
WebStudio.Application.prototype.updateFloatingMenuPosition = function() 
{
	this.StartEditControl.el.setStyles({
		top: this.getWindowSize().h - 70,
		left: 15
	});
}

/**
 * Initializes the floating menu display
 */
WebStudio.Application.prototype.showFloatingMenu = function()
{
	// default, hide stuff
	this.StartEditControl.el.style.display = "none";
	
	// Check whether the user is authenticated
	if(this.userAuth())
	{		
		// Check whether we've picked a sandbox
		if(this.sandboxMounted())
		{
			this.StartEditControl.el.style.display = "";
		}
	}
}

/**
 * Toggles between editing mode and non-editing mode
 */
WebStudio.Application.prototype.toggleEdit = function() 
{
	if (this.editState == 'view')
	{
		this.startEdit();
	}
	else
	{
		this.endEdit();
	}
	return this;
}

/**
 * Flips the application into 'editing' mode
 * This brings up the application overlays
 */
WebStudio.Application.prototype.startEdit = function() 
{
	if(!this.applicationsBootstrapped)
	{
		this.startApplications();
		return false;
	}
		
	this.activeMenu.showFast();

	if (!this.isHideDockingPanel)
	{
		this.panels.showPanels();
	}

	this.setEditControlCaption(WebStudio.context.getStoreId());
	    
	this.panels.generalLayer.setStyle('margin-top', this.getTopOffset());
	this.panels.setHeight(this.panels.getHeight() - this.getTopOffset());
	this.editState = 'edit';
	this.updateFloatingMenuPosition();

	this.onPanelsResize(WebStudio.app.panels.firstPanel.offsetWidth,WebStudio.app.panels.secondPanel.offsetWidth);
		
	return this;
}

/**
 * Flips the application into 'non-editing' mode
 * This turns off the application overlays
 */
WebStudio.Application.prototype.endEdit = function() 
{
	if (!this.isHideDockingPanel) 
	{
		this.panels.hidePanel(true);
	}
	
	this.setEditControlCaption(WebStudio.context.getStoreId());
	
	this.panels.generalLayer.setStyle('margin-top', 0);
	this.panels.setHeight(this.panels.getHeight() + this.getTopOffset());
	this.activeMenu.hide();
	this.editState = 'view';
	this.resizePanel();
	this.updateFloatingMenuPosition();
	this.PanelsHolder.el.style.top = "0px";
	this.activeMenu.addEvent('onHideComplete', 'AlfrescoApplicationHide', this.resizePanel, this);
	if(this.pageEditor)
	{
		this.pageEditor.hideTabItems();
	}
	
	var webdesigner = this.getApplication("webdesigner");
	if(webdesigner)
	{
		webdesigner.hideAllDesigners();
	}
	
	//this.activeMenu = null;
	this.onPanelsResize(WebStudio.app.panels.firstPanel.offsetWidth,WebStudio.app.panels.secondPanel.offsetWidth);
	
	return this;
}

/**
 * Sets the text for the edit control
 */
WebStudio.Application.prototype.setEditControlCaption = function(text) 
{
	this.StartEditControl[0].ContentEditCaption.el.setHTML(text);
}

/**
 * Toggles the display of the left-hand panel
 */
WebStudio.Application.prototype.toggleSlidersPanel = function() 
{
	if (!this.isHideDockingPanel) {
		this.hideSlidersPanel();
	} else {
		this.showSlidersPanel();
	}

	this.onPanelsResize(WebStudio.app.panels.firstPanel.offsetWidth,WebStudio.app.panels.secondPanel.offsetWidth);
	return this;
}

/**
 * Hides the left-hand panel
 */
WebStudio.Application.prototype.hideSlidersPanel = function() 
{
	this.panels.hidePanel(true);
	this.isHideDockingPanel = true;
	
	if(this.pageEditor)
	{
		var app = this.getApplication("webdesigner");
		if(app)
		{
			app.hidePageEditor();
			app.showPageEditor();
		}
	}
	
	return this;
}

/**
 * Shows the left-hand panel
 */
WebStudio.Application.prototype.showSlidersPanel = function() 
{
	this.panels.showPanels();
	this.isHideDockingPanel = false;

	if(this.pageEditor)
	{
		this.getApplication("webdesigner").hidePageEditor();
		this.getApplication("webdesigner").showPageEditor();
	}

	return this;
}

/**
 * Tells the application to recalculate all resize dependencies
 */
WebStudio.Application.prototype.resize = function() 
{
	this.resizePanel();
	this.resizeSlidersSector();
	this.updateFloatingMenuPosition();
    this.resizeWindow();
}

WebStudio.Application.prototype.resizeWindow = function () 
{
    WebStudio.app.generalLayer.setStyles({
        'width' : this.getWindowSize().w,
        'height' : this.getWindowSize().h
    });
    
    for(var appId in this.applications)
    {
    	var application = this.applications[appId];
    	if(application)
    	{
    		application.resize();
    	}
    }
}

WebStudio.Application.prototype.resizePanel = function() 
{
    this.panels.setHeight(10);
    var h = this.getWindowSize().h;
    var w = this.getWindowSize().w;

    this.panels.setWidth(w);
    h = this.panels.container.offsetWidth > w ? h - 20 : h;
    this.panels.setHeight(h - (this.editState == "edit" ? 20 : 2));

    if (window.opera && this.panels.secondPanel.childNodes[4])
    { 
    	//Fix for stupid opera bug
        this.panels.secondPanel.getElementsBySelector('table')[0].rows[0].cells[0].height = "100%";
    }
        
    return this;
}

WebStudio.Application.prototype.resizeSlidersSector = function() 
{
	if(this.slidersSector != null)
	{
		this.slidersSector.reOpenActiveSlider();
	}
}

WebStudio.Application.prototype.refreshBrowser = function()
{
	window.location.reload(true);
}

WebStudio.Application.prototype.blockNotify = function(msg)
{
	if(!this.blockNotifyModal)
	{
		this.blockNotifyModal = new YAHOO.widget.Panel("blockNotify", {
			fixedcenter: true,
			close: false, 
			draggable: false,
			width: 250,
			height: 0,
			modal: true,
			visible: false,
			effect:{effect:YAHOO.widget.ContainerEffect.FADE, duration:0.5} 			
		});
	
		this.blockNotifyModal.setHeader(msg);
	    this.blockNotifyModal.setBody("<img src='<%=overlayPath%>/images/rel_interstitial_loading.gif'/>");
	    this.blockNotifyModal.render($(document.body));
	}
	else
	{
		this.blockNotifyModal.setHeader(msg);
	}
	
	// move to center
	this.blockNotifyModal.center();
	this.blockNotifyModal.show();
}

WebStudio.Application.prototype.clearBlockNotify = function()
{
	if(this.blockNotifyModal)
	{
		this.blockNotifyModal.hide();
	}
}

WebStudio.Application.prototype.onMenuItemClick = function(appId, id)
{
	if(!this.applicationsBootstrapped)
	{
		var postFunction = (function()
		{
			this.startEdit();
			
			var app = this.getApplication(appId);
			if(app)
			{
				app.onMenuItemClick(id);
			}	
		}).bind(this);

		this.startApplications(postFunction);
	}
	else
	{
		var app = this.getApplication(appId);
		if(app)
		{
			app.onMenuItemClick(id);
		}	
	}
}

WebStudio.Application.prototype.openBrowser = function(name, url)
{
	if(!name)
	{
		name = "_blank";
	}
	
	var args = "fullscreen";
	if (window.screen) 
	{
		w = window.screen.availWidth;
		h = window.screen.availHeight;
		args = "width="+w+",height="+h+",top=0,left=0";
	}
	args += ",location=1,status=1,scrollbars=1";
	window.open(url, name, args);
}