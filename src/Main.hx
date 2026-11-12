package mods.classic_settings;

import facade.DBFacade;
import mods.api.Context;
import mods.api.Mod;
import openfl.display.DisplayObject;
import openfl.display.DisplayObjectContainer;
import openfl.display.MovieClip;
import openfl.events.Event;
import settings.SettingsPopup;
import stateMachine.mainStateMachine.TownState;
import town.HomeState;
import town.TownStateMachine;

/**
 * Main entry point for the Classic Settings mod.
 *
 * Dungeon Rampage doesn't have a direct "settings opened" event for mods,
 * so this class checks on every frame whether the settings menu has been opened.
 * When found, it hands the popup MovieClip over to SettingsReskinner to give it
 * the classic town wooden board, red ribbon header, and gold typography.
 */
class Main extends Mod {
	var context:Context;
	var facade:Null<DBFacade>;
	var art:Null<SettingsReskinArt>;
	var reskinner:Null<SettingsReskinner>;

	// Keep track of clips we've already reskinned so we don't do the work twice
	var reskinnedClips:Map<DisplayObject, Bool> = new Map();

	override public function init(context:Context):Void {
		this.context = context;
	}

	override public function ready(context:Context):Void {
		facade = context.core.facade;
		if (facade == null) return;

		// Load art assets (wood board & red ribbon from the town SWF)
		art = new SettingsReskinArt(facade);
		reskinner = new SettingsReskinner(facade, art);

		// Listen to each frame so we catch the moment the settings popup appears
		context.overlay.addEventListener(Event.ENTER_FRAME, onFrame);
		context.log("Classic Settings mod loaded.");
	}

	override public function dispose():Void {
		if (context != null && context.overlay != null) {
			context.overlay.removeEventListener(Event.ENTER_FRAME, onFrame);
		}
		if (reskinner != null) {
			reskinner.destroy();
			reskinner = null;
		}
		if (art != null) {
			art.destroy();
			art = null;
		}
		reskinnedClips.clear();
		facade = null;
	}

	function onFrame(event:Event):Void {
		// Wait until the town art assets are fully loaded and ready
		if (facade == null || reskinner == null || art == null || !art.townReady) {
			return;
		}

		// Look for an open settings popup that hasn't been reskinned yet
		var popupClip = findSettingsPopupClip();
		if (popupClip != null && !reskinnedClips.exists(popupClip)) {
			var popupObj = findSettingsPopupObject();
			if (reskinner.reskin(popupClip, popupObj)) {
				reskinnedClips.set(popupClip, true);
				context.log("Settings popup reskinned successfully.");
			}
		}
	}

	/**
	 * Locates the SettingsPopup logical object from the game's state machine.
	 *
	 * Having the logical SettingsPopup instance allows us to access structured
	 * components like mTabs, mList, and mResetButton directly, rather than
	 * having to guess display indices in the raw MovieClip.
	 */
	function findSettingsPopupObject():Null<SettingsPopup> {
		if (facade == null) return null;

		// 1. In town: check TownState -> TownStateMachine -> HomeState.mSettingsPopup
		var state:Dynamic = facade.mainStateMachine != null ? facade.mainStateMachine.currentState : null;
		if (state != null) {
			if (Std.isOfType(state, HomeState)) {
				var homeState:HomeState = cast state;
				var p:Dynamic = @:privateAccess homeState.mSettingsPopup;
				if (p != null) return cast p;
			}

			if (Std.isOfType(state, TownState)) {
				var ts:TownState = cast state;
				var tsm:TownStateMachine = ts.townStateMachine;
				if (tsm != null) {
					var sub:Dynamic = tsm.currentState;
					if (sub != null && Std.isOfType(sub, HomeState)) {
						var hs:HomeState = cast sub;
						var p:Dynamic = @:privateAccess hs.mSettingsPopup;
						if (p != null) return cast p;
					}
					var hs2:HomeState = @:privateAccess tsm.mHomeState;
					if (hs2 != null) {
						var p:Dynamic = @:privateAccess hs2.mSettingsPopup;
						if (p != null) return cast p;
					}
				}
			}

			// Reflection fallback for different build variations
			var tsm:Dynamic = Reflect.getProperty(state, "townStateMachine");
			if (tsm == null) tsm = Reflect.field(state, "mTownStateMachine");
			if (tsm != null) {
				var home:Dynamic = Reflect.getProperty(tsm, "currentState");
				if (home == null) home = Reflect.field(tsm, "mHomeState");
				if (home != null) {
					var p:Dynamic = Reflect.field(home, "mSettingsPopup");
					if (p != null && Std.isOfType(p, SettingsPopup)) {
						return cast p;
					}
				}
			}
		}

		// 2. In dungeon / match: check the HUD reference
		var hud:Dynamic = facade.hud;
		if (hud != null) {
			var p:Dynamic = Reflect.field(hud, "mSettingsPopup");
			if (p != null && Std.isOfType(p, SettingsPopup)) {
				return cast p;
			}
		}

		return null;
	}

	/**
	 * Finds the visual MovieClip of the settings popup.
	 * First tries using the popup object reference, then falls back
	 * to searching layer 105 (the game's UI popup layer).
	 */
	function findSettingsPopupClip():Null<MovieClip> {
		if (facade == null) return null;

		// Direct access via the popup object if available
		var popupObj = findSettingsPopupObject();
		if (popupObj != null) {
			var clip:Null<MovieClip> = @:privateAccess popupObj.mPopup;
			if (clip != null) return clip;
		}

		// Fallback: search the popup layer in the scene graph
		var layer = facade.sceneGraphManager != null ? facade.sceneGraphManager.getLayer(105) : null;
		if (layer != null) {
			return searchForSettingsClip(layer);
		}

		return null;
	}

	/**
	 * Recursively scans a container to find the MovieClip that matches
	 * the unique structure of the Settings popup.
	 */
	function searchForSettingsClip(container:DisplayObjectContainer):Null<MovieClip> {
		var i = 0;
		while (i < container.numChildren) {
			var child = container.getChildAt(i);
			if (child != null && Std.isOfType(child, MovieClip)) {
				var mc:MovieClip = cast child;
				if (isSettingsPopupClip(mc)) {
					return mc;
				}
				if (mc.numChildren > 0) {
					var nested = searchForSettingsClip(mc);
					if (nested != null) return nested;
				}
			}
			i++;
		}
		return null;
	}

	/**
	 * Verifies whether a MovieClip is indeed the settings popup by checking
	 * for elements unique to this screen (the scroll panel or tab buttons).
	 */
	static function isSettingsPopupClip(mc:MovieClip):Bool {
		return mc.getChildByName("panel_two_scroll_panel") != null || mc.getChildByName("panel_2") != null;
	}
}
