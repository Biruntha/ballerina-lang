/*
 * Copyright (c) 2019, WSO2 Inc. (http://wso2.com) All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package events;

import com.sun.jdi.AbsentInformationException;
import com.sun.jdi.Location;
import com.sun.jdi.VMDisconnectedException;
import com.sun.jdi.VirtualMachine;
import com.sun.jdi.event.BreakpointEvent;
import com.sun.jdi.event.ClassPrepareEvent;
import com.sun.jdi.event.Event;
import com.sun.jdi.event.EventSet;
import com.sun.jdi.request.BreakpointRequest;
import org.eclipse.lsp4j.debug.Breakpoint;
import org.eclipse.lsp4j.debug.StoppedEventArguments;
import org.eclipse.lsp4j.debug.StoppedEventArgumentsReason;
import org.eclipse.lsp4j.debug.services.IDebugProtocolClient;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.concurrent.CompletableFuture;
import java.util.function.Consumer;
import java.util.stream.Collectors;

public class EventBus {
    private Breakpoint[] breakpointsList = new Breakpoint[0];
    public EventSet eventSet = null;

    public void setBreakpointsList(Breakpoint[] breakpointsList) {
        this.breakpointsList = breakpointsList;
    }

    public void startListening(VirtualMachine debuggee, IDebugProtocolClient client) {
        CompletableFuture.runAsync(() -> {
                    try {
                        while ((eventSet = debuggee.eventQueue().remove(100)) != null) {

                            for (Event event : eventSet) {

                                /*
                                 * If this is ClassPrepareEvent, then set breakpoint
                                 */
                                if (event instanceof ClassPrepareEvent) {
                                    ClassPrepareEvent evt = (ClassPrepareEvent) event;

                                    Arrays.stream(this.breakpointsList).forEach(breakpoint -> {
                                        String balName = evt.referenceType().name() + ".bal";
                                        if (balName.equals(breakpoint.getSource().getName())) {
                                            Location location = null;
                                            try {
                                                location = evt.referenceType().locationsOfLine(breakpoint.getLine().intValue()).get(0);
                                            } catch (AbsentInformationException e) {
                                                e.printStackTrace();
                                            }
                                            BreakpointRequest bpReq = debuggee.eventRequestManager().createBreakpointRequest(location);
                                            bpReq.enable();
                                        }
                                    });
                                }

                                /*
                                 * If this is BreakpointEvent, then read & print variables.
                                 */
                                if (event instanceof BreakpointEvent) {
                                    // disable the breakpoint event
                                    event.request().disable();
                                    StoppedEventArguments stoppedEventArguments = new StoppedEventArguments();
                                    stoppedEventArguments.setReason(StoppedEventArgumentsReason.BREAKPOINT);
                                    stoppedEventArguments.setThreadId(((BreakpointEvent) event).thread().uniqueID());
                                    client.stopped(stoppedEventArguments);
//                        }
                                }
                                else {
                                    eventSet.resume();
                                }
                            }

                        }
                    } catch (VMDisconnectedException e) {
                        System.out.println("VM is now disconnected.");
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }
        );
    }
}
