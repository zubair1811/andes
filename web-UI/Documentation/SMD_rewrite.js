{
	"envelope": "JSON-RPC-2.0",
	"transport": "POST",
	"target": "/help",
	"SMDVersion": "2.0",
	"parameters": [
		{"name": "time", "type": "number"}
	],
	"services": {
		"open-problem": {
			"parameters": [
				{"name": "user", "type": "string"},
				{"name": "problem", "type": "string"}
			],
			"returns":{
				"type": "object",
				"items":{
					"type": "array",
					"item": {
						"type": "object",
						"id": {
							"description": "Identifier for each drawn item, set by the creator of the object.  Used only by actions new-object, modify-object, and delete-object",
							"type": "string", 
							"optional": true
						},
						"type": {
							"description": "kind of drawn object; manditory for new-object and optional for modify-object or delete-object",
							"type": "string",
							"enum": [
								"text", "graphics", "equation", "circle", "rectangle", "axes", "vector", "line"
							],
							"optional": true
						},
						"mode": {
							"description": "manditory for new-object and optional for modify-object or delete-object\n  unknown:  turn black\n  correct:  turn green\n  wrong:  turn red\n  locked:  black, not user selectable\n  fade:  gray, not user selectable",
							"type": "string",
							"enum": ["unknown","right","wrong","locked","fade"],
							"optional": true
						},
						"x": {
							"type": "number",
							"optional": true
						},
						"y": {
							"type": "number",
							"optional": true
						},
						"width": {
							"type": "integer",
							"optional": true
						},
						"height": {
							"type": "integer",
							"optional": true
						},
						"text":{
							"type": "string",
							"optional": true
						},
						"radius":{
							"type": "number",
							"optional": true
						},
						"symbol": {
							"type": "string",
							"optional": true
						},
						"x-label":{
							"type": "string",
							"optional": true
						},
						"y-label":{
							"type": "string",
							"optional": true
						},
						"angle": {
							"type": "number",
							"optional": true
						}
					}
				},
				"score": {
					"type": ["object","number"],
					"optional": true
				}
			}
		},
		"solution-step": {
			"parameters": [
				{
					"name": "action",
					"type": "string",
					"enum":["new-object","modify-object", "delete-object"]
				},
				{
					"name": "id",
					"type": "string",
					"optional": true,
					"description": "Identifier for each drawn item, set by the creator of the object. Used only by actions new-object, modify-object, and delete-object"
				},
				{
					"name": "type",
					"type": "string",
					"enum": ["text", "graphics", "equation", "circle", "rectangle", "axes", "vector", "line"],
					"optional": true,
					"description": "kind of drawn object; manditory for new-object and optional for modify-object or delete-object"
				},
				{
					"name": "mode",
					"type": "string",
					"enum": ["unknown","right","wrong","locked","fade"],
					"optional": true,
					"description": "manditory for new-object and optional for modify-object or delete-object\n  unknown:  turn black\n  correct:  turn green\n  wrong:  turn red\n  locked:  black, not user selectable\n  fade:  gray, not user selectable"
				},
				{"name": "x", "type": "number", "optional": true},
				{"name": "y", "type": "number", "optional": true},
				{"name": "width", "type": "integer", "optional": true}, 
				{"name": "height", "type": "integer", "optional": true},
				{"name": "text", "type": "string", "optional": true},
				{"name": "radius", "type": "number", "optional": true},
				{"name": "symbol", "type": "string", "optional": true},
				{"name": "x-label", "type": "string", "optional": true},
				{"name": "y-label", "type": "string", "optional": true},
				{"name": "angle", "type": "number", "optional": true}
			],
			"returns":{
				"type": "object",
				"score": {
					"type": ["object","number"],
					"optional": true
				},
				"mode": {
					"type": "string",
					"enum": ["unknown","right","wrong","locked","fade"],
					"optional": true,
					"description": "response for new-object, modify-object or delete-object.\n  unknown:  turn black\n  correct:  turn green\n  wrong:  turn red\n  locked:  black, not user selectable\n  fade:  gray, not user selectable"
				}
		},
		"seek-help": {
			"parameters": [
				{
					"name": "action",
					"type": "string",
					"enum":["get-help","help-button","principles-menu"]
				},
				{"name": "href", "type": "string", "optional": true},
				{"name": "value", "type": "string", "optional": true},
				{"name": "text", "type": "string", "optional": true}
			]
		},
		"close-problem": {
			"parameters": [
				{
					"name": "json smd bug: can't just inherit parameters and get named parameters",
					"type": "string",
					"optional": true
				}
			]
		}
	},
	
	"returns": {
		"type": "array",
		"items": {
			"type": "object",
			"properties": {
				"action": {
					"type": "string",
					"description": "The choice get-help is only from the  client while\nthe choices set-score, show-hint, show-hint-link, and focus-hint-text-box are only from the server. \nLog actions are not read by the client and my be stripped from any response sent to the client. This is just a first attempt at the client-server API, any suggestions are welcome.",
					"enum":[
							"new-object",
							"modify-object",
							"delete-object",
							"log",
							"get-help",
							"help-button",
							"set-score",
							"show-hint",
							"show-hint-link",
							"focus-hint-text-box"
					]
				},
			"id": {
				"description": "Identifier for each drawn item, set by the creator of the object.  Used only by actions new-object, modify-object, and delete-object",
				"type": "string",  //CHANGED - was number
				"optional": true
			},
			"type": {
				"description": "kind of drawn object; manditory for new-object and optional for modify-object or delete-object",
				"type": "string",
				"enum": [
					"text", "graphics", "equation", "circle", "rectangle", "axes", "vector", "line"
				],
				"optional": true
			},
			"mode": {
				"description": "manditory for new-object and optional for modify-object or delete-object\n  unknown:  turn black\n  correct:  turn green\n  wrong:  turn red\n  locked:  black, not user selectable\n  fade:  gray, not user selectable",
				"type": "string",
				"enum": ["unknown","right","wrong","locked","fade"],
				"optional": true
			},
			"score": {"type": ["object","number"], "optional": true}
			
			
			// on startup, this needs to return everything from above
			
			
		}
	}
}}