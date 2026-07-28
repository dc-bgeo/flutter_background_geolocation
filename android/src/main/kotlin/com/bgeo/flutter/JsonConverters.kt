package com.bgeo.flutter

import org.json.JSONArray
import org.json.JSONObject

/** JSONObject (engine) <-> Map/List (Flutter StandardMessageCodec). */
fun JSONObject.toMap(): Map<String, Any?> = keys().asSequence().associateWith { k ->
    when (val v = get(k)) {
        is JSONObject -> v.toMap()
        is JSONArray -> v.toList()
        JSONObject.NULL -> null
        else -> v
    }
}

fun JSONArray.toList(): List<Any?> = (0 until length()).map { i ->
    when (val v = get(i)) {
        is JSONObject -> v.toMap()
        is JSONArray -> v.toList()
        JSONObject.NULL -> null
        else -> v
    }
}

fun Map<*, *>.toJSONObject(): JSONObject = JSONObject().also { o ->
    forEach { (k, v) -> o.put(k.toString(), wrapJson(v)) }
}

fun List<*>.toJSONArray(): JSONArray = JSONArray().also { a ->
    forEach { a.put(wrapJson(it)) }
}

private fun wrapJson(v: Any?): Any = when (v) {
    null -> JSONObject.NULL
    is Map<*, *> -> v.toJSONObject()
    is List<*> -> v.toJSONArray()
    else -> v
}
