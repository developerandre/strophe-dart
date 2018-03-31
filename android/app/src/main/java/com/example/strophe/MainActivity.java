package com.example.strophe;

import android.os.Bundle;

import java.lang.reflect.Array;
import java.util.ArrayList;
import java.util.Arrays;

import io.flutter.app.FlutterActivity;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FlutterActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        GeneratedPluginRegistrant.registerWith(this);
        new MethodChannel(getFlutterView(), "flutter.channel/sasl")
                .setMethodCallHandler(new MethodChannel.MethodCallHandler() {
                    @Override
                    public void onMethodCall(MethodCall methodCall, MethodChannel.Result result) {
                        if (methodCall.method.equals("rol")) {
                            ArrayList arguments = (ArrayList) methodCall.arguments;
                            if(arguments.size() < 2){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            if (!(arguments.get(0) instanceof Integer)) {
                                result.error("Argument Error", "first argument must be integer", null);
                                return;
                            }
                            if (!(arguments.get(1) instanceof Integer)) {
                                result.error("Argument Error", "second argument must be integer", null);
                                return;
                            }
                            result.success(SHA1.rol((int) arguments.get(0), (int) arguments.get(1)));

                        } else if (methodCall.method.equals("core_sha1")) {
                            ArrayList arguments = (ArrayList) methodCall.arguments;
                            if(arguments.size() < 2){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            if (!(arguments.get(0) instanceof int[])) {
                                result.error("Argument Error", "first argument must be array of integer", null);
                                return;
                            }
                            if (!(arguments.get(1) instanceof Integer)) {
                                result.error("Argument Error", "second argument must be integer", null);
                                return;
                            }
                            result.success(SHA1.core_sha1((int[]) arguments.get(0), (int) arguments.get(1)));
                        } else if (methodCall.method.equals("core_hmac_sha1")) {
                            ArrayList arguments = (ArrayList) methodCall.arguments;
                            if(arguments.size() < 2){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            if (!(arguments.get(0) instanceof String)) {
                                result.error("Argument Error", "first argument must be String", null);
                                return;
                            }
                            if (!(arguments.get(1) instanceof String)) {
                                result.error("Argument Error", "second argument must be String", null);
                                return;
                            }
                            result.success(SHA1.core_hmac_sha1((String) arguments.get(0), (String) arguments.get(1)));
                        } else if (methodCall.method.equals("safe_add")) {
                            ArrayList arguments = (ArrayList) methodCall.arguments;
                            if(arguments.size() < 2){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            if (!(arguments.get(0) instanceof Integer)) {
                                result.error("Argument Error", "first argument must be int", null);
                                return;
                            }
                            if (!(arguments.get(1) instanceof Integer)) {
                                result.error("Argument Error", "second argument must be int", null);
                                return;
                            }
                            result.success(SHA1.safe_add((int) arguments.get(0), (int) arguments.get(1)));
                        } else if (methodCall.method.equals("str2binb")) {
                            ArrayList arguments = (ArrayList) methodCall.arguments;
                            if(arguments.size() < 1){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            if (!(arguments.get(0) instanceof String)) {
                                result.error("Argument Error", "first argument must be String", null);
                                return;
                            }
                            result.success(SHA1.str2binb((String) arguments.get(0)));
                        } else if (methodCall.method.equals("b64_sha1")) {
                            ArrayList arguments = (ArrayList) methodCall.arguments;
                            if(arguments.size() < 1){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            if (!(arguments.get(0) instanceof String)) {
                                result.error("Argument Error", "first argument must be String", null);
                                return;
                            }
                            result.success(SHA1.b64_sha1((String) arguments.get(0)));
                        } else if (methodCall.method.equals("str_sha1")) {
                            ArrayList arguments = (ArrayList) methodCall.arguments;
                            if(arguments.size() < 1){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            if (!(arguments.get(0) instanceof String)) {
                                result.error("Argument Error", "first argument must be String", null);
                                return;
                            }
                            result.success(SHA1.str_sha1((String) arguments.get(0)));
                        } else if (methodCall.method.equals("str_hmac_sha1")) {
                            ArrayList arguments = (ArrayList) methodCall.arguments;
                            if(arguments.size() < 2){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            if (!(arguments.get(0) instanceof String)) {
                                result.error("Argument Error", "first argument must be String", null);
                                return;
                            }
                            if (!(arguments.get(1) instanceof String)) {
                                result.error("Argument Error", "second argument must be String", null);
                                return;
                            }
                            result.success(SHA1.str_hmac_sha1((String) arguments.get(0), (String) arguments.get(1)));
                        } else if (methodCall.method.equals("b64_hmac_sha1")) {
                            ArrayList arguments = (ArrayList) methodCall.arguments;
                            if(arguments.size() < 2){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            if (!(arguments.get(0) instanceof String)) {
                                result.error("Argument Error", "first argument must be String", null);
                                return;
                            }
                            if (!(arguments.get(1) instanceof String)) {
                                result.error("Argument Error", "second argument must be String", null);
                                return;
                            }
                            result.success(SHA1.b64_hmac_sha1((String) arguments.get(0), (String) arguments.get(1)));
                        } else if (methodCall.method.equals("binb2str")) {
                            ArrayList arguments = (ArrayList) methodCall.arguments;
                            if(arguments.size() < 1){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            if (!(arguments.get(0) instanceof int[])) {
                                result.error("Argument Error", "first argument must be array of integer", null);
                                return;
                            }
                            result.success(SHA1.binb2str((int[]) arguments.get(0)));
                        } else if (methodCall.method.equals("binb2b64")) {
                            ArrayList arguments = (ArrayList) methodCall.arguments;
                            if(arguments.size() < 1){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            if (!(arguments.get(0) instanceof int[])) {
                                result.error("Argument Error", "first argument must be array of integer", null);
                                return;
                            }
                            result.success(SHA1.binb2b64((int[]) arguments.get(0)));
                        }
                        // MD5
                        else if (methodCall.method.equals("md5_safe_add")) {
                            ArrayList arguments = (ArrayList) methodCall.arguments;
                            if(arguments.size() < 2){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            if (!(arguments.get(0) instanceof Integer)) {
                                result.error("Argument Error", "first argument must be int", null);
                                return;
                            }
                            if (!(arguments.get(1) instanceof Integer)) {
                                result.error("Argument Error", "second argument must be int", null);
                                return;
                            }
                            result.success(MD5.safe_add((int) arguments.get(0), (int) arguments.get(1)));

                        }
                        else if (methodCall.method.equals("bit_rol")) {
                            ArrayList arguments = (ArrayList) methodCall.arguments;
                            if(arguments.size() < 2){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            if (!(arguments.get(0) instanceof Integer)) {
                                result.error("Argument Error", "first argument must be int", null);
                                return;
                            }
                            if (!(arguments.get(1) instanceof Integer)) {
                                result.error("Argument Error", "second argument must be int", null);
                                return;
                            }
                            result.success(MD5.bit_rol((int) arguments.get(0), (int) arguments.get(1)));

                        }
                        else if (methodCall.method.equals("str2binl")) {
                            ArrayList arguments = (ArrayList) methodCall.arguments;
                            if(arguments.size() < 1){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            if (!(arguments.get(0) instanceof String)) {
                                result.error("Argument Error", "first argument must be String", null);
                                return;
                            }
                            result.success(MD5.str2binl((String) arguments.get(0)));
                        }else if (methodCall.method.equals("binl2str")) {
                            ArrayList arguments = (ArrayList) methodCall.arguments;
                            if(arguments.size() < 1){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            if (!(arguments.get(0) instanceof int[])) {
                                result.error("Argument Error", "first argument must be array of integer", null);
                                return;
                            }
                            result.success(MD5.binl2str((int[]) arguments.get(0)));
                        }else if (methodCall.method.equals("binl2hex")) {
                            ArrayList arguments = (ArrayList) methodCall.arguments;
                            if(arguments.size() < 1){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            if (!(arguments.get(0) instanceof int[])) {
                                result.error("Argument Error", "first argument must be array of integer", null);
                                return;
                            }
                            result.success(MD5.binl2hex((int[]) arguments.get(0)));
                        }else if (methodCall.method.equals("core_md5")) {
                            ArrayList arguments = (ArrayList) methodCall.arguments;
                            if(arguments.size() < 2){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            if (!(arguments.get(0) instanceof int[])) {
                                result.error("Argument Error", "first argument must be array of integer", null);
                                return;
                            }
                            if (!(arguments.get(1) instanceof Integer)) {
                                result.error("Argument Error", "second argument must be integer", null);
                                return;
                            }
                            result.success(MD5.core_md5((int[]) arguments.get(0), (int) arguments.get(1)));
                        }
                        else if (methodCall.method.equals("md5_cmn")) {
                            ArrayList<Integer> arguments = (ArrayList<Integer>) methodCall.arguments;
                            if(arguments.size() < 6){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            result.success(MD5.md5_cmn((int) arguments.get(0), (int) arguments.get(1),(int) arguments.get(2), (int) arguments.get(3),(int) arguments.get(4), (int) arguments.get(5)));
                        }
                        else if (methodCall.method.equals("md5_ff")) {
                            ArrayList<Integer> arguments = (ArrayList<Integer>) methodCall.arguments;
                            if(arguments.size() < 7){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            result.success(MD5.md5_ff((int) arguments.get(0), (int) arguments.get(1),(int) arguments.get(2), (int) arguments.get(3),(int) arguments.get(4), (int) arguments.get(5),(int) arguments.get(6)));
                        }else if (methodCall.method.equals("md5_gg")) {
                            ArrayList<Integer> arguments = (ArrayList<Integer>) methodCall.arguments;
                            if(arguments.size() < 7){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            result.success(MD5.md5_gg((int) arguments.get(0), (int) arguments.get(1),(int) arguments.get(2), (int) arguments.get(3),(int) arguments.get(4), (int) arguments.get(5),(int) arguments.get(6)));
                        }else if (methodCall.method.equals("md5_hh")) {
                            ArrayList<Integer> arguments = (ArrayList<Integer>) methodCall.arguments;
                            if(arguments.size() < 7){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            result.success(MD5.md5_hh((int) arguments.get(0), (int) arguments.get(1),(int) arguments.get(2), (int) arguments.get(3),(int) arguments.get(4), (int) arguments.get(5),(int) arguments.get(6)));
                        }else if (methodCall.method.equals("md5_ii")) {
                            ArrayList<Integer> arguments = (ArrayList<Integer>) methodCall.arguments;
                            if(arguments.size() < 7){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            result.success(MD5.md5_ii((int) arguments.get(0), (int) arguments.get(1),(int) arguments.get(2), (int) arguments.get(3),(int) arguments.get(4), (int) arguments.get(5),(int) arguments.get(6)));
                        }
                        else if (methodCall.method.equals("hexdigest")) {
                            ArrayList arguments = (ArrayList) methodCall.arguments;
                            if(arguments.size() < 1){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            if (!(arguments.get(0) instanceof String)) {
                                result.error("Argument Error", "first argument must be String", null);
                                return;
                            }
                            result.success(MD5.hexdigest((String) arguments.get(0)));
                        }else if (methodCall.method.equals("hash")) {
                            ArrayList arguments = (ArrayList) methodCall.arguments;
                            if(arguments.size() < 1){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            if (!(arguments.get(0) instanceof String)) {
                                result.error("Argument Error", "first argument must be String", null);
                                return;
                            }
                            result.success(MD5.hash((String) arguments.get(0)));
                        }
                        // utility
                        else if (methodCall.method.equals("forEachBinaryXor")) {
                            ArrayList arguments = (ArrayList) methodCall.arguments;
                            if(arguments.size() < 3){
                                result.error("Argument Size Error", "size array error", null);
                                return;
                            }
                            if (!(arguments.get(0) instanceof int[])) {
                                result.error("Argument Error", "first argument must be String", null);
                                return;
                            }
                            if (!(arguments.get(1) instanceof int[])) {
                                result.error("Argument Error", "first argument must be String", null);
                                return;
                            }
                            if (!(arguments.get(2) instanceof Integer)) {
                                result.error("Argument Error", "first argument must be String", null);
                                return;
                            }
                            result.success(SHA1.forEachBinaryXor((int[]) arguments.get(0),(int[]) arguments.get(1),(int) arguments.get(2)));
                        }
                        else {
                            result.notImplemented();
                        }
                    }
                });
    }

}
