package mods.classic_settings;

import brain.assetRepository.AssetLoadingComponent;
import brain.assetRepository.SwfAsset;
import facade.DBFacade;
import openfl.display.DisplayObject;
import openfl.display.MovieClip;

/**
 * Handles loading and extracting original art assets from the game's town SWF.
 *
 * Rather than shipping custom PNGs or duplicate art, this class taps directly
 * into `db_UI_town.swf` from the game's art repository. This gives us the genuine
 * vector wooden plank board (popup_base) and the classic red ribbon banner,
 * keeping the mod lightweight and visually authentic to pre-1.0 Dungeon Rampage.
 */
class SettingsReskinArt {
	public static inline final TOWN_SWF = "Resources/Art2D/UI/db_UI_town.swf";

	public var townReady(get, never):Bool;

	var loader:AssetLoadingComponent;
	var townAsset:Null<SwfAsset>;

	public function new(facade:DBFacade, onReady:Void->Void = null) {
		loader = new AssetLoadingComponent(facade);
		loader.getSwfAsset(DBFacade.buildFullDownloadPath(TOWN_SWF), function(asset:SwfAsset) {
			townAsset = asset;
			if (onReady != null) {
				onReady();
			}
		});
	}

	function get_townReady():Bool {
		return townAsset != null;
	}

	/**
	 * Creates an instance of the town popup symbol, which contains
	 * the wooden board (`popup_base`) with its metallic borders and rivets.
	 */
	public function popup():Null<MovieClip> {
		return townSymbol("popup");
	}

	/**
	 * Extracts the authentic red ribbon banner from the town assets.
	 *
	 * We specifically pull the ribbon from `UI_town_train` (the training camp menu)
	 * because in the original SWF, that symbol was authored with Flash 9-slice scaling.
	 * This allows us to stretch the banner horizontally without distorting the ribbon's
	 * curved ends or folds. If that symbol isn't available, it falls back to the
	 * standard `banner_title_label` from the generic popup.
	 */
	public function banner():Null<DisplayObject> {
		var train = townSymbol("UI_town_train");
		if (train != null) {
			// Find the ribbon child inside the training clip by its unscaled dimensions
			for (i in 0...train.numChildren) {
				var child = train.getChildAt(i);
				if (child != null && child.width > 300 && child.width < 450 && child.height > 60 && child.height < 120) {
					train.removeChild(child);
					return child;
				}
			}
			// Fallback: child index 6 is the ribbon's default depth in UI_town_train
			if (train.numChildren > 6) {
				var c6 = train.getChildAt(6);
				if (c6 != null) {
					train.removeChild(c6);
					return c6;
				}
			}
		}

		// Fallback to the generic popup banner if training menu ribbon wasn't found
		var p = popup();
		if (p != null) {
			var b = p.getChildByName("banner_title_label");
			if (b != null) {
				p.removeChild(b);
				return b;
			}
		}
		return null;
	}

	/**
	 * Instantiates a raw MovieClip symbol from the loaded town SWF by its exported class name.
	 */
	public function townSymbol(name:String):Null<MovieClip> {
		if (townAsset == null) return null;
		var type:Dynamic = townAsset.getClass(name);
		return type == null ? null : cast ASCompat.createInstance(type, []);
	}

	public function destroy():Void {
		if (loader != null) {
			loader.destroy();
		}
		townAsset = null;
	}
}
