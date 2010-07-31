dojo.provide("andes.principles");
dojo.require("dijit.Tree");
dojo.require("dojo.data.ItemFileReadStore");
dojo.require("dojo.data.ItemFileReadStore");

// Modify tree so that HTML is rendered in node labels
// See Bug #1603
dijit._TreeNode._meta.hidden.attributeMap.label.type="innerHTML";

// The principles and other review pages can be opened either 
// via the menus or via the help system (links in the Tutor pane).
andes.principles={
	
	// Either constants or Equations.
	reviewp: null,
	review: function(file,title,dimensionString){
		var dims = dimensionString?dimensionString+",scrollbars=no":"width=350,height=450,scrollbars=yes";
		this.reviewp=window.open("../review/"+file,
					 title,
					 dims+",directories=no,menubar=no,toolbar=no,location=no,status=no"
					);
		this.reviewp && this.reviewp.focus();
	},
	
	extp: null,
	externP: function (){
		if(!this.extp || this.extp.closed){
			// See https://developer.mozilla.org/en/DOM/window.open
			this.extp=window.open("../review/principles-tree.html","Principles",
					      // Default starting size in Firefox is too big, need to set explicitly.
					      // Need scrollbars=1 in Firefox for reopen with long (opened) tree.
					      // status=0 ignored by Firefox.
					      "width=350,height=450,scrollbars=yes,directories=no,menubar=no,toolbar=no,location=no,status=no"
					     );
			// If this fails, open a Modal dialog.
			if(!this.extp) {
				// Delete any text leftover from old hints.
   				dojo.byId("allModalTreeText").innerHTML = "";
				dijit.byId("allPrinciples").show();
			}
		}
		this.extp && this.extp.focus();
	}
}

// This should be loaded after everything else, in the background
dojo.addOnLoad(function() {
	
	var principlesStore = new dojo.data.ItemFileReadStore({
		url: "../review/principles.json"
	});
	
	var majorPrinciplesModel = new dijit.tree.ForestStoreModel({
		store: principlesStore,
		query: {"complexity": "major"},
		rootLabel: "Major Principles",
		childrenAttrs: ["items"]
	});
	
	var allPrinciplesModel = new dijit.tree.ForestStoreModel({
		store: principlesStore,
		rootLabel: "All Principles",
		childrenAttrs: ["items"]
	});
	
	new dijit.Tree({
		model: majorPrinciplesModel,
		showRoot: false,
		onClick: function(item,node) {
			var psm=principlesStore.getValue(item,"psm");
			// if student clicks on a group, there is no psm.
			if(psm){
				andes.help.echo(principlesStore.getValue(item,"label"));
				andes.help.principles(psm);
				dijit.byId("majorPrinciples").hide();
			}
		}
	},"majorModalTree");
	
	new dijit.Tree({
		model: allPrinciplesModel,
		showRoot: false,
		onClick: function(item,node) {
			var psm=principlesStore.getValue(item,"psm");
			// if student clicks on a group, there is no psm.
			if(psm){
				andes.help.echo(principlesStore.getValue(item,"label"));
				andes.help.principles(psm);
				// This is a bit ugly, but close both possible windows:
				dijit.byId("allPrinciples").hide();
			}
		}
	},"allModalTree");
	
});
