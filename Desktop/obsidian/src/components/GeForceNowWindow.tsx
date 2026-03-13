import React, { useState, useRef, useEffect } from 'react';
import {
    View,
    Text,
    StyleSheet,
    TouchableOpacity,
    TextInput,
    Pressable,
    Platform,
    useWindowDimensions,
    Image,
} from 'react-native';
import { WebView } from 'react-native-webview';
import Animated, { FadeIn, FadeOut, useSharedValue, useAnimatedStyle, withSpring, withTiming, withRepeat, Easing } from 'react-native-reanimated';
import { BlurView } from 'expo-blur';
import {
    X,
    Minus,
    Maximize2,
    RotateCw,
    Search,
} from 'lucide-react-native';
import { GestureDetector, Gesture } from 'react-native-gesture-handler';

interface Props { 
    onClose: () => void; 
    onMinimize: () => void;
    isMinimized: boolean;
    onFullscreenChange?: (isFullscreen: boolean) => void;
}

const styles = StyleSheet.create({
    window: {
        position: 'absolute',
        top: 0, 
        left: 0,
        borderRadius: 14,
        overflow: 'hidden',
        backgroundColor: '#000',
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 20 },
        shadowOpacity: 0.7,
        shadowRadius: 40,
        elevation: 30,
        zIndex: 2000,
        borderWidth: 1,
        borderColor: 'rgba(118,185,0,0.2)', // Suble NVIDIA Green
    },
    titleBarWrapper: {
        height: 40,
        cursor: 'move' as any,
    },
    titleBar: {
        height: 40,
        flexDirection: 'row',
        alignItems: 'center',
        paddingHorizontal: 14,
        backgroundColor: '#1a1a1a',
        borderBottomWidth: 1,
        borderBottomColor: '#000',
    },
    trafficLights: {
        flexDirection: 'row',
        gap: 7,
        marginRight: 20,
    },
    dot: {
        width: 12,
        height: 12,
        borderRadius: 6,
        alignItems: 'center',
        justifyContent: 'center',
    },
    titleContainer: {
        flex: 1,
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 8,
        marginRight: 32,
    },
    appIcon: {
        width: 18,
        height: 18,
    },
    titleText: {
        color: '#e8eaed',
        fontSize: 12,
        fontWeight: '600',
    },
    reloadBtn: {
        padding: 6,
    },
    webviewContainer: {
        flex: 1,
        backgroundColor: '#000',
    },
    webview: {
        flex: 1,
        backgroundColor: '#000',
    },
    resizeHandle: {
        position: 'absolute',
        bottom: 0,
        right: 0,
        width: 20,
        height: 20,
        cursor: 'se-resize' as any,
        justifyContent: 'flex-end',
        alignItems: 'flex-end',
        padding: 4,
    },
    resizeGrip: {
        width: 0,
        height: 0,
        borderBottomWidth: 10,
        borderBottomColor: 'rgba(118,185,0,0.3)',
        borderLeftWidth: 10,
        borderLeftColor: 'transparent',
    },
    loadingOverlay: {
        ...StyleSheet.absoluteFillObject,
        zIndex: 10,
    },
    loaderContainer: {
        flex: 1,
        alignItems: 'center',
        justifyContent: 'center',
        gap: 15,
    },
    loadingText: {
        color: '#76b900',
        fontSize: 14,
        fontWeight: '500',
        textShadowColor: 'rgba(0,0,0,0.5)',
        textShadowOffset: { width: 0, height: 1 },
        textShadowRadius: 4,
    }
});

// --- macOS Traffic Lights ---
interface TrafficLightProps {
    onClose: () => void;
    onMinimize: () => void;
    onMaximize: () => void;
}

const TrafficLights = ({ onClose, onMinimize, onMaximize }: TrafficLightProps) => {
    const [hovered, setHovered] = useState(false);

    return (
        <View 
            style={styles.trafficLights}
            {...Platform.select({
                web: {
                    onPointerEnter: () => setHovered(true),
                    onPointerLeave: () => setHovered(false),
                }
            })}
        >
            <Pressable onPress={onClose} style={[styles.dot, { backgroundColor: '#FF5F57' }]}>
                {hovered && <X size={8} color="#4c0000" strokeWidth={3} />}
            </Pressable>
            <Pressable onPress={onMinimize} style={[styles.dot, { backgroundColor: '#FFBD2E' }]}>
                {hovered && <Minus size={8} color="#5a3d00" strokeWidth={3} />}
            </Pressable>
            <Pressable onPress={onMaximize} style={[styles.dot, { backgroundColor: '#28C840' }]}>
                {hovered && <Maximize2 size={6} color="#004d00" strokeWidth={3} />}
            </Pressable>
        </View>
    );
};

export const GeForceNowWindow: React.FC<Props> = ({ onClose, onMinimize, isMinimized, onFullscreenChange }) => {
    const { width: scrW, height: scrH } = useWindowDimensions();
    const webRef = useRef<WebView | null>(null);
    const [isLoading, setIsLoading] = useState(true);

    // -- Window dragging / resizing state --
    const [isMax, setIsMax] = useState(false);
    
    // Default window geometry
    const W_W = Math.min(scrW * 0.9, 1000);
    const W_H = Math.min(scrH * 0.85, 750);
    const START_X = (scrW - W_W) / 2;
    const START_Y = Math.max(44, (scrH - W_H) / 2 - 20);

    const winX = useSharedValue(START_X);
    const winY = useSharedValue(START_Y);
    const winW = useSharedValue(W_W);
    const winH = useSharedValue(W_H);

    const offsetX = useSharedValue(0);
    const offsetY = useSharedValue(0);
    const prevWinX = useSharedValue(START_X);
    const prevWinY = useSharedValue(START_Y);
    const prevWinW = useSharedValue(W_W);
    const prevWinH = useSharedValue(W_H);

    const minimizeAnim = useSharedValue(0);

    useEffect(() => {
        const springConfig = { damping: 30, stiffness: 200 };
        minimizeAnim.value = withSpring(isMinimized ? 1 : 0, springConfig);
        
        if (isMinimized && isMax) {
            if (onFullscreenChange) onFullscreenChange(false);
        } else if (!isMinimized && isMax) {
            if (onFullscreenChange) onFullscreenChange(true);
        }
    }, [isMinimized, isMax]);

    const offsetW = useSharedValue(0);
    const offsetH = useSharedValue(0);

    const dragGesture = Gesture.Pan()
        .onStart(() => {
            offsetX.value = winX.value;
            offsetY.value = winY.value;
        })
        .onUpdate((e) => {
            if (isMax) return;
            winX.value = offsetX.value + e.translationX;
            winY.value = Math.max(32, offsetY.value + e.translationY);
        });

    const resizeGesture = Gesture.Pan()
        .onStart(() => {
            offsetW.value = winW.value;
            offsetH.value = winH.value;
        })
        .onUpdate((e) => {
            if (isMax) return;
            winW.value = Math.max(400, offsetW.value + e.translationX);
            winH.value = Math.max(300, offsetH.value + e.translationY);
        });

    const toggleMaximize = () => {
        const springConfig = { damping: 25, stiffness: 400 };
        if (isMax) {
            winX.value = withSpring(prevWinX.value, springConfig);
            winY.value = withSpring(prevWinY.value, springConfig);
            winW.value = withSpring(prevWinW.value, springConfig);
            winH.value = withSpring(prevWinH.value, springConfig);
            setIsMax(false);
            if (onFullscreenChange) onFullscreenChange(false);
        } else {
            prevWinX.value = winX.value;
            prevWinY.value = winY.value;
            prevWinW.value = winW.value;
            prevWinH.value = winH.value;
            
            winX.value = withSpring(0, springConfig);
            winY.value = withSpring(32, springConfig);
            winW.value = withSpring(scrW, springConfig);
            winH.value = withSpring(scrH - 32 + 5, springConfig);
            setIsMax(true);
            if (onFullscreenChange) onFullscreenChange(true);
        }
    };

    const animatedWinStyle = useAnimatedStyle(() => ({
        transform: [
            { translateX: winX.value }, 
            { translateY: winY.value + (minimizeAnim.value * (scrH - winY.value)) },
            { scale: 1 - (minimizeAnim.value * 0.8) }
        ] as any,
        width: winW.value,
        height: winH.value,
        opacity: withSpring(isMinimized ? 0 : 1, { damping: 30, stiffness: 200 }),
    }));

    // Loading Spin Animation
    const spinValue = useSharedValue(0);
    useEffect(() => {
        if (isLoading) {
            spinValue.value = withRepeat(
                withTiming(1, { duration: 1000, easing: Easing.linear }),
                -1,
                false
            );
        } else {
            spinValue.value = 0;
        }
    }, [isLoading]);

    const spinStyle = useAnimatedStyle(() => ({
        transform: [{ rotate: `${spinValue.value * 360}deg` }]
    }));

    // Windows Chrome - most unambiguous desktop UA. Server-side detection happens here.
    const desktopUA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36";

    // Tell the server we're a Windows desktop at the HTTP header level
    const DESKTOP_HEADERS = {
        'User-Agent': desktopUA,
        'Sec-CH-UA': '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
        'Sec-CH-UA-Mobile': '?0',
        'Sec-CH-UA-Platform': '"Windows"',
        'Accept-Language': 'it-IT,it;q=0.9,en-US;q=0.8,en;q=0.7',
        'Cache-Control': 'no-cache',
    };

    // ULTIMATE NUCLEAR SPOOFING: Falsify EVERYTHING before any site script runs
    const DEEP_SPOOF = `
        (function() {
            try {
                const desktopUA = "${desktopUA}";
                const spoofedPlatform = "Win32";
                
                // Redefine navigator entirely to bypass read-only restrictions
                const originalNavigator = window.navigator;
                const spoofedNavigator = Object.create(originalNavigator);
                
                const wrap = (prop, value) => {
                    Object.defineProperty(spoofedNavigator, prop, { get: () => value, configurable: true });
                };

                wrap('userAgent', desktopUA);
                wrap('appVersion', desktopUA);
                wrap('platform', spoofedPlatform);
                wrap('vendor', 'Google Inc.');
                wrap('deviceMemory', 8);
                wrap('hardwareConcurrency', 8);
                wrap('maxTouchPoints', 0);
                wrap('languages', ['it-IT', 'it', 'en-US', 'en']);
                
                // Hide iOS markers
                wrap('standalone', false);
                
                Object.defineProperty(window, 'navigator', { value: spoofedNavigator, configurable: true });

                // 2. Nuke Touch APIs (Crucial for GFN PC detection)
                delete window.ontouchstart;
                delete window.ontouchend;
                delete window.ontouchmove;
                delete window.ontouchcancel;
                window.Touch = undefined;
                window.TouchEvent = undefined;
                window.TouchList = undefined;

                // 3. Spoof the 'window.chrome' object
                window.chrome = {
                    runtime: {},
                    loadTimes: function() {},
                    csi: function() {},
                    app: { isInstalled: false }
                };

                // 4. Force orientation to landscape (PC)
                if (window.screen && window.screen.orientation) {
                    Object.defineProperty(window.screen.orientation, 'type', { get: () => 'landscape-primary' });
                }
            } catch(e) { console.log("Spoof fail:", e); }
        })();
        true;
    `;

    // Fullscreen shim + Suppression of mobile prompts
    const INJECTED_AFTER = `
        (function() {
            try {
                // Fullscreen API Shim
                const goFullscreen = (v) => {
                    if (v && v.webkitEnterFullscreen) {
                        v.webkitEnterFullscreen();
                        return true;
                    }
                    return false;
                };

                const originalRequest = Element.prototype.requestFullscreen || Element.prototype.webkitRequestFullscreen;
                Element.prototype.requestFullscreen = function() {
                    const video = this.tagName === 'VIDEO' ? this : this.querySelector('video');
                    if (video && goFullscreen(video)) return Promise.resolve();
                    return originalRequest ? originalRequest.apply(this, arguments) : Promise.reject();
                };

                function kill() {
                    // Force CSS to hide THE ENTIRE iOS gatekeeper layer
                    const style = document.createElement('style');
                    style.innerHTML = \`
                        /* Hide PWA prompts, overlays and iOS specifically forced UI */
                        [data-testid="pwa-install-prompt"], [class*="PwaModal"], [class*="pwaModal"], 
                        [class*="AddToHome"], [class*="addToHome"], .pwa-prompt, .install-banner, 
                        .mobile-upsell, .add-to-home, .ios-guide, .pwa-installer, #install-prompt, 
                        .gatekeeper-container, .ios-gatekeeper, .pwa-overlay, .modal-backdrop {
                            display: none !important; visibility: hidden !important; opacity: 0 !important; pointer-events: none !important;
                        }
                        
                        /* Force show the main app content and login buttons */
                        #app-root, .app-root, body, html, #main-content, .login-container {
                            display: block !important; visibility: visible !important; opacity: 1 !important; pointer-events: auto !important;
                        }

                        /* Ensure scrolling is enabled (GFN mobile disables it) */
                        body, html { overflow: auto !important; position: static !important; }
                    \`;
                    document.head.appendChild(style);

                    const selectors = [
                        '[data-testid="pwa-install-prompt"]', '[class*="PwaModal"]', '.pwa-prompt', 
                        '.install-banner', '.mobile-upsell', '.add-to-home', '.ios-guide', 
                        '.pwa-installer', '#install-prompt', '.upsell-modal', '.footer-upsell', 
                        '.install-button-container', '.gatekeeper-container'
                    ];
                    
                    document.querySelectorAll(selectors.join(',')).forEach(el => el.remove());

                    // If we find a "Login" button that's hidden, force it
                    document.querySelectorAll('button, a').forEach(el => {
                        if (el.textContent.toLowerCase().includes('accedi') || el.textContent.toLowerCase().includes('login')) {
                            el.style.display = 'block';
                            el.style.visibility = 'visible';
                        }
                    });

                    // Also fix window.open for auth
                    if (!window.__openFixed) {
                        window.__openFixed = true;
                        var _open = window.open;
                        window.open = function(url) {
                            if (url) { window.location.href = url; return window; }
                            return _open.apply(this, arguments);
                        };
                    }
                }
                kill();
                new MutationObserver(kill).observe(document.documentElement, { childList: true, subtree: true });
            } catch(e) {}
        })();
        true;
    `;

    return (
        <Animated.View
            entering={FadeIn.duration(150)}
            exiting={FadeOut.duration(100)}
            style={[styles.window, animatedWinStyle]}
            pointerEvents={isMinimized ? 'none' : 'auto'}
        >
            {/* ── Title Bar (Draggable Area) ── */}
            <GestureDetector gesture={dragGesture}>
                <Animated.View style={styles.titleBarWrapper}>
                    <BlurView intensity={80} tint="dark" style={styles.titleBar}>
                        <TrafficLights 
                            onClose={onClose} 
                            onMinimize={onMinimize}
                            onMaximize={toggleMaximize} 
                        />
                        <View style={styles.titleContainer}>
                            <Image 
                                source={{ uri: 'https://img.icons8.com/color/48/000000/nvidia.png' }} 
                                style={styles.appIcon} 
                            />
                            <Text style={styles.titleText}>GeForce NOW</Text>
                        </View>
                        <TouchableOpacity style={styles.reloadBtn} onPress={() => webRef.current?.reload()}>
                            <RotateCw size={14} color={isLoading ? '#76b900' : '#e8eaed'} />
                        </TouchableOpacity>
                    </BlurView>
                </Animated.View>
            </GestureDetector>

            {/* ── WebView Area ── */}
            <View style={styles.webviewContainer}>
                <WebView
                    ref={webRef}
                    source={{ 
                        uri: 'https://play.geforcenow.com',
                        headers: DESKTOP_HEADERS,
                    }}
                    style={styles.webview}
                    userAgent={desktopUA}
                    injectedJavaScriptBeforeContentLoaded={DEEP_SPOOF}
                    injectedJavaScript={INJECTED_AFTER}
                    onLoadStart={() => setIsLoading(true)}
                    onLoadEnd={() => setIsLoading(false)}
                    allowsFullscreenVideo={true}
                    domStorageEnabled={true}
                    javaScriptEnabled={true}
                    mediaPlaybackRequiresUserAction={false}
                    allowsInlineMediaPlayback={true}
                    sharedCookiesEnabled={true}
                    thirdPartyCookiesEnabled={true}
                    cacheEnabled={true}
                    incognito={false}
                    originWhitelist={['*']}
                    setSupportMultipleWindows={false}
                    javaScriptCanOpenWindowsAutomatically={true}
                />
                
                {isLoading && (
                    <View style={styles.loadingOverlay}>
                        <BlurView intensity={20} tint="dark" style={StyleSheet.absoluteFill}>
                            <View style={styles.loaderContainer}>
                                <Animated.View style={spinStyle}>
                                    <RotateCw size={30} color="#76b900" />
                                </Animated.View>
                                <Text style={styles.loadingText}>Connessione a GeForce NOW...</Text>
                            </View>
                        </BlurView>
                    </View>
                )}
            </View>

            {/* ── Resize Handle ── */}
            {!isMax && (
                <GestureDetector gesture={resizeGesture}>
                    <Animated.View style={styles.resizeHandle}>
                        <View style={styles.resizeGrip} />
                    </Animated.View>
                </GestureDetector>
            )}
        </Animated.View>
    );
};
