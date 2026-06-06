import React, { useRef, useEffect, useState, useCallback } from 'react';
import {
  View,
  Text,
  ScrollView,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  Animated,
  KeyboardAvoidingView,
  Platform,
  SafeAreaView,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { Colors } from '../../constants/colors';

// TODO: wire up ElevenLabs WebSocket
// Agent ID comes from env: process.env.EXPO_PUBLIC_ELEVENLABS_AGENT_ID

interface Message {
  id: string;
  role: 'user' | 'agent';
  content: string;
}

let messageIdCounter = 0;
function nextId(): string {
  return String(++messageIdCounter);
}

export default function TalkScreen() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [isConnected, setIsConnected] = useState(false);
  const [isMuted, setIsMuted] = useState(false);
  const [agentIsSpeaking, setAgentIsSpeaking] = useState(false);
  const [connectionStatus, setConnectionStatus] = useState('Ready');
  const [textInput, setTextInput] = useState('');
  const [detectedEmotion, setDetectedEmotion] = useState<string | null>(null);

  const scrollViewRef = useRef<ScrollView>(null);
  const pulseAnim = useRef(new Animated.Value(1)).current;
  const pulseOpacity = useRef(new Animated.Value(0.7)).current;
  const pulseLoop = useRef<Animated.CompositeAnimation | null>(null);

  // Start/stop orb pulse animation when agent is speaking
  useEffect(() => {
    if (agentIsSpeaking) {
      pulseLoop.current = Animated.loop(
        Animated.sequence([
          Animated.parallel([
            Animated.timing(pulseAnim, {
              toValue: 1.12,
              duration: 600,
              useNativeDriver: true,
            }),
            Animated.timing(pulseOpacity, {
              toValue: 1,
              duration: 600,
              useNativeDriver: true,
            }),
          ]),
          Animated.parallel([
            Animated.timing(pulseAnim, {
              toValue: 1,
              duration: 600,
              useNativeDriver: true,
            }),
            Animated.timing(pulseOpacity, {
              toValue: 0.7,
              duration: 600,
              useNativeDriver: true,
            }),
          ]),
        ])
      );
      pulseLoop.current.start();
    } else {
      pulseLoop.current?.stop();
      pulseAnim.setValue(1);
      pulseOpacity.setValue(0.7);
    }

    return () => {
      pulseLoop.current?.stop();
    };
  }, [agentIsSpeaking, pulseAnim, pulseOpacity]);

  // Scroll to bottom on new messages
  useEffect(() => {
    if (messages.length > 0) {
      setTimeout(() => {
        scrollViewRef.current?.scrollToEnd({ animated: true });
      }, 80);
    }
  }, [messages]);

  // --- Stub connection handlers ---

  const handleStartConversation = useCallback(() => {
    setConnectionStatus('Connecting...');
    // TODO: initiate ElevenLabs WebSocket session
    // Simulated transition for UI demo
    setTimeout(() => {
      setIsConnected(true);
      setConnectionStatus('Connected');
      // Demo: agent greets
      setMessages((prev) => [
        ...prev,
        {
          id: nextId(),
          role: 'agent',
          content: 'Hello! How can I help you today?',
        },
      ]);
      setAgentIsSpeaking(true);
      setTimeout(() => setAgentIsSpeaking(false), 2000);
    }, 1000);
  }, []);

  const handleEndConversation = useCallback(() => {
    setIsConnected(false);
    setIsMuted(false);
    setAgentIsSpeaking(false);
    setConnectionStatus('Ended');
    // TODO: close ElevenLabs WebSocket session
  }, []);

  const handleOrbPress = useCallback(() => {
    if (isConnected) {
      setIsMuted((prev) => !prev);
      // TODO: mute/unmute microphone track
    } else {
      handleStartConversation();
    }
  }, [isConnected, handleStartConversation]);

  const handleSendText = useCallback(() => {
    const trimmed = textInput.trim();
    if (!trimmed) return;
    setMessages((prev) => [
      ...prev,
      { id: nextId(), role: 'user', content: trimmed },
    ]);
    setTextInput('');
    // TODO: send text message over ElevenLabs WebSocket
  }, [textInput]);

  // --- Orb gradient colors ---
  const orbColors: [string, string, string] = isConnected
    ? [Colors.sunshine500, Colors.primary, Colors.primaryDeep]
    : ['#b0b0b0', '#808080', '#606060'];

  return (
    <SafeAreaView style={styles.safeArea}>
      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        keyboardVerticalOffset={Platform.OS === 'ios' ? 88 : 0}
      >
        {/* Emotion banner */}
        {detectedEmotion !== null && (
          <View style={styles.emotionBanner}>
            <Text style={styles.emotionText}>{detectedEmotion}</Text>
          </View>
        )}

        {/* Message list */}
        <ScrollView
          ref={scrollViewRef}
          style={styles.messageList}
          contentContainerStyle={styles.messageListContent}
          showsVerticalScrollIndicator={false}
        >
          {messages.length === 0 && (
            <Text style={styles.emptyHint}>
              Tap the orb to start a conversation.
            </Text>
          )}
          {messages.map((msg) => (
            <View
              key={msg.id}
              style={[
                styles.bubbleRow,
                msg.role === 'user' ? styles.bubbleRowUser : styles.bubbleRowAgent,
              ]}
            >
              <View
                style={[
                  styles.bubble,
                  msg.role === 'user' ? styles.bubbleUser : styles.bubbleAgent,
                ]}
              >
                <Text
                  style={
                    msg.role === 'user'
                      ? styles.bubbleTextUser
                      : styles.bubbleTextAgent
                  }
                >
                  {msg.content}
                </Text>
              </View>
            </View>
          ))}
        </ScrollView>

        {/* Orb + status + buttons */}
        <View style={styles.orbSection}>
          {/* Orb */}
          <Animated.View
            style={[
              styles.orbWrapper,
              {
                transform: [{ scale: pulseAnim }],
                opacity: pulseOpacity,
              },
            ]}
          >
            <TouchableOpacity
              activeOpacity={0.85}
              onPress={handleOrbPress}
              style={styles.orbTouchable}
            >
              <LinearGradient
                colors={orbColors}
                start={{ x: 0.2, y: 0 }}
                end={{ x: 0.8, y: 1 }}
                style={styles.orb}
              >
                {isConnected && (
                  <Text style={styles.orbIcon}>{isMuted ? '🔇' : '🎙️'}</Text>
                )}
              </LinearGradient>
            </TouchableOpacity>
          </Animated.View>

          {/* Status label */}
          <Text style={styles.statusLabel}>{connectionStatus}</Text>

          {/* Start / End buttons */}
          <View style={styles.buttonRow}>
            {!isConnected ? (
              <TouchableOpacity
                style={[styles.actionButton, styles.startButton]}
                onPress={handleStartConversation}
                activeOpacity={0.8}
              >
                <Text style={styles.actionButtonText}>Start</Text>
              </TouchableOpacity>
            ) : (
              <TouchableOpacity
                style={[styles.actionButton, styles.endButton]}
                onPress={handleEndConversation}
                activeOpacity={0.8}
              >
                <Text style={styles.actionButtonText}>End</Text>
              </TouchableOpacity>
            )}
          </View>
        </View>

        {/* Text input fallback */}
        <View style={styles.inputRow}>
          <TextInput
            style={styles.textInput}
            value={textInput}
            onChangeText={setTextInput}
            placeholder="Type a message…"
            placeholderTextColor={Colors.muted}
            returnKeyType="send"
            onSubmitEditing={handleSendText}
          />
          <TouchableOpacity
            style={[
              styles.sendButton,
              textInput.trim().length === 0 && styles.sendButtonDisabled,
            ]}
            onPress={handleSendText}
            disabled={textInput.trim().length === 0}
            activeOpacity={0.8}
          >
            <Text style={styles.sendButtonText}>Send</Text>
          </TouchableOpacity>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: Colors.canvas,
  },
  flex: {
    flex: 1,
  },

  // Emotion banner
  emotionBanner: {
    backgroundColor: Colors.sunshine300,
    paddingVertical: 8,
    paddingHorizontal: 16,
    alignItems: 'center',
  },
  emotionText: {
    fontSize: 14,
    fontWeight: '600',
    color: Colors.ink,
  },

  // Message list
  messageList: {
    flex: 1,
  },
  messageListContent: {
    paddingVertical: 16,
    paddingHorizontal: 12,
    flexGrow: 1,
    justifyContent: 'flex-end',
  },
  emptyHint: {
    textAlign: 'center',
    color: Colors.muted,
    fontSize: 14,
    marginTop: 32,
  },
  bubbleRow: {
    marginBottom: 8,
    flexDirection: 'row',
  },
  bubbleRowUser: {
    justifyContent: 'flex-end',
  },
  bubbleRowAgent: {
    justifyContent: 'flex-start',
  },
  bubble: {
    maxWidth: '78%',
    paddingVertical: 10,
    paddingHorizontal: 14,
    borderRadius: 18,
  },
  bubbleUser: {
    backgroundColor: Colors.ink,
    borderBottomRightRadius: 4,
  },
  bubbleAgent: {
    backgroundColor: Colors.cream,
    borderBottomLeftRadius: 4,
  },
  bubbleTextUser: {
    color: Colors.canvas,
    fontSize: 15,
    lineHeight: 20,
  },
  bubbleTextAgent: {
    color: Colors.ink,
    fontSize: 15,
    lineHeight: 20,
  },

  // Orb section
  orbSection: {
    alignItems: 'center',
    paddingVertical: 20,
    paddingHorizontal: 24,
    backgroundColor: Colors.creamLight,
    borderTopWidth: 1,
    borderTopColor: Colors.hairline,
  },
  orbWrapper: {
    width: 100,
    height: 100,
    borderRadius: 50,
    shadowColor: Colors.primary,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.45,
    shadowRadius: 12,
    elevation: 10,
    marginBottom: 12,
  },
  orbTouchable: {
    width: 100,
    height: 100,
    borderRadius: 50,
    overflow: 'hidden',
  },
  orb: {
    width: 100,
    height: 100,
    borderRadius: 50,
    alignItems: 'center',
    justifyContent: 'center',
  },
  orbIcon: {
    fontSize: 28,
  },
  statusLabel: {
    fontSize: 14,
    color: Colors.steel,
    fontWeight: '500',
    marginBottom: 16,
    letterSpacing: 0.3,
  },
  buttonRow: {
    flexDirection: 'row',
    gap: 12,
  },
  actionButton: {
    paddingVertical: 10,
    paddingHorizontal: 32,
    borderRadius: 22,
    minWidth: 100,
    alignItems: 'center',
  },
  startButton: {
    backgroundColor: Colors.primary,
  },
  endButton: {
    backgroundColor: Colors.steel,
  },
  actionButtonText: {
    color: Colors.canvas,
    fontSize: 15,
    fontWeight: '600',
  },

  // Text input row
  inputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 10,
    borderTopWidth: 1,
    borderTopColor: Colors.hairline,
    backgroundColor: Colors.canvas,
    gap: 8,
  },
  textInput: {
    flex: 1,
    height: 40,
    borderRadius: 20,
    backgroundColor: Colors.surface,
    borderWidth: 1,
    borderColor: Colors.hairline,
    paddingHorizontal: 16,
    fontSize: 15,
    color: Colors.ink,
  },
  sendButton: {
    paddingVertical: 8,
    paddingHorizontal: 18,
    borderRadius: 20,
    backgroundColor: Colors.primary,
  },
  sendButtonDisabled: {
    backgroundColor: Colors.muted,
  },
  sendButtonText: {
    color: Colors.canvas,
    fontWeight: '600',
    fontSize: 14,
  },
});
