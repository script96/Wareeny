package com.wareeny.wareeny

import android.content.Context
import io.flutter.embedding.engine.loader.FlutterLoader
import org.json.JSONObject

data class IndoorNavigationModelConfig(
    val modelPath: String,
    val labelsPath: String,
    val inputSize: Int,
    val confidenceThreshold: Float,
    val nmsThreshold: Float,
) {
    companion object {
        private const val MANIFEST_ASSET = "assets/models/indoor_navigation/manifest.json"

        fun load(
            context: Context,
            flutterLoader: FlutterLoader,
        ): IndoorNavigationModelConfig {
            val key = flutterLoader.getLookupKeyForAsset(MANIFEST_ASSET)
            val json = context.assets.open(key).bufferedReader().use { reader ->
                JSONObject(reader.readText())
            }

            return IndoorNavigationModelConfig(
                modelPath = json.optString(
                    "modelPath",
                    "assets/models/indoor_navigation/model.tflite",
                ),
                labelsPath = json.optString(
                    "labelsPath",
                    "assets/models/indoor_navigation/labels.txt",
                ),
                inputSize = json.optInt("inputSize", 640),
                confidenceThreshold = json.optDouble("confidenceThreshold", 0.35).toFloat(),
                nmsThreshold = json.optDouble("nmsThreshold", 0.45).toFloat(),
            )
        }
    }
}
