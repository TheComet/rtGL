function varargout = gui(varargin)

    % Begin initialization code - DO NOT EDIT
    gui_Singleton = 1;
    gui_State = struct('gui_Name',       mfilename, ...
                       'gui_Singleton',  gui_Singleton, ...
                       'gui_OpeningFcn', @gui_OpeningFcn, ...
                       'gui_OutputFcn',  @gui_OutputFcn, ...
                       'gui_LayoutFcn',  [] , ...
                       'gui_Callback',   []);
    if nargin && ischar(varargin{1})
        gui_State.gui_Callback = str2func(varargin{1});
    end
    if nargout
        [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
    else
        gui_mainfcn(gui_State, varargin{:});
    end
    % End initialization code - DO NOT EDIT

% ------------------------------------------------------------------------------------------------------------------------
function gui_OpeningFcn(hObject, eventdata, handles, varargin)

    global path_gui
    path_gui = pwd;

    try
        fopen(serial('IMPOSSIBLE_NAME_ON_PORT'));
    end

    handles.output = hObject;
    guidata(hObject, handles);
    figureToolBar = uimenu(handles.figure1,'Label','Zoom Functions');
    uimenu(figureToolBar,'Label','Zoom In','Callback','zoom on');
    uimenu(figureToolBar,'Label','Zoom Out','Callback','zoom out');
    uimenu(figureToolBar,'Label','Pan','Callback','pan on'); 

    populate_popup_menus(handles)
    
    set(handles.uipanel_auto_man,'SelectionChangeFcn',@selection_auto_man);
    set(handles.uipanel_controller_type,'SelectionChangeFcn',@selection_controller_type);
    
    global t_limit_active timr
    t_limit_active = 0;
    timr = cell(2,1);
    
% ------------------------------------------------------------------------------------------------------------------------
function varargout = gui_OutputFcn(hObject, eventdata, handles) 

    varargout{1} = handles.output;

% ------------------------------------------------------------------------------------------------------------------------
function figure1_CloseRequestFcn(hObject, eventdata, handles)

    stop_serial_and_timer
    delete(hObject);

% ------------------------------------------------------------------------------------------------------------------------
function text_serial_port_Callback(hObject, eventdata, handles)

    prompt = {'Enter serial port:'};
    dlg_title = 'Serial port';
    num_lines = 1;
    def = {''};
    answer = inputdlg(prompt,dlg_title,num_lines,def);
    if isempty(answer)
        populate_popup_menus(handles)
        return
    else
        str = answer{1};
        if isempty(str)
            populate_popup_menus(handles)
        else
            populate_popup_menus(handles,str)
        end % if
    end % if
    
% ------------------------------------------------------------------------------------------------------------------------
function pushbutton_connect_Callback(hObject, eventdata, handles)

    global obj_serial signals timr signal_names verbose
    
    verbose = 0;
    set(handles.pushbutton_connect,'Enable','off')
    
    if strcmp(get(handles.pushbutton_connect,'String'),'Disconnect')

        % Close serial connection and stop timer
        stop_serial_and_timer

        set(handles.pushbutton_connect,'String','Connect')
        set(handles.pushbutton_connect,'Enable','on')
        set_enable(handles,'off')
        
    else

        getData()

        % Define serial connection
        serial_type = 1; % 1 = pop-up menu, 2 = manual
        switch serial_type
            case 1 % definition using pop-up menus
                dummy = get(handles.popupmenu_serial_port,'String');
                if strcmp(dummy(get(handles.popupmenu_serial_port,'Value')),'')
                    disp('Serial port is empty.')
                    return
                else
                    serialport = dummy{get(handles.popupmenu_serial_port,'Value')};
                end % if
                dummy = get(handles.popupmenu_baud_rate,'String');
                if strcmp(dummy(get(handles.popupmenu_baud_rate,'Value')),'')
                    disp('Baud rate is empty.')
                    return
                else
                    baudrate = str2double(dummy{get(handles.popupmenu_baud_rate,'Value')});
                end % if
                obj_serial = serial(serialport,'BaudRate',baudrate);                
            case 2 % manual definition in the code
                obj_serial = serial('COM4','BaudRate',57600); % enter the required settings here
        end % switch

        % Open serial connection
        try
            fopen(obj_serial)
            signal_names = {'t','y','r','e','u','u_sat','integrator','K_P','T_N','T_V','T_f','u_man','automatic','u_max','u_min','e_lower','e_upper','e_middle1','e_middle2','u_lower','u_middle','u_upper','dt','controller_type','ddt'};
            signals = clear_signals;
            tic % Start timer
            t_timeout = 5;
            str = 'Connecting';
            set(handles.pushbutton_connect,'String',str)
            while (1)
                pause(0.5)
                str = [str, '.'];
                set(handles.pushbutton_connect,'String',str)
                if (obj_serial.BytesAvailable) % Serial communication working
                    fgetl(obj_serial); % Get a single line in order to make sure that the following lines are complete
                    while (1)
                        getData(obj_serial,handles)
                        if ~isempty(signals.dt)
                            break
                        else
                            pause(0.1)
                        end % if
                    end % while
                    pause(signals.dt(end)*0.9)
                    dt_timer = max(0.001,round(0.6*signals.dt(end)*1000)/1000);
                    timr{1} = timer('TimerFcn', @(x,y)getData(obj_serial,handles), 'Period', dt_timer);
                    set(timr{1},'ExecutionMode','fixedRate');
                    start(timr{1});
                    dt_timer2 = 1;
                    timr{2} = timer('TimerFcn', @(x,y)refresh_figure(handles), 'Period', dt_timer2);
                    set(timr{2},'ExecutionMode','fixedRate');
                    start(timr{2});
                    set(handles.pushbutton_connect,'String','Disconnect')
                    set_enable(handles,'on')
                    break
                end % if
                if (toc > t_timeout) % Timeout reached
                    errordlg('Serial connection failed. Wrong serial port?');
                    set(handles.pushbutton_connect,'String','Connect')
                    fclose(obj_serial);
                    break
                end % if
            end % while
        catch exception
            exception_handling(exception)
            errordlg('Serial connection failed. Port occupied by Arduino IDE?');
            set(handles.pushbutton_connect,'String','Connect')
            set(handles.pushbutton_connect,'Enable','on')
            fclose(obj_serial)
        end % try
        set(handles.pushbutton_connect,'Enable','on')

    end % if

% ------------------------------------------------------------------------------------------------------------------------
function pushbutton_export_Callback(hObject, eventdata, handles)

    set(handles.pushbutton_export,'Enable','off')
    export_signals
    set(handles.pushbutton_export,'Enable','on')

% ------------------------------------------------------------------------------------------------------------------------
function pushbutton_print_Callback(hObject, eventdata, handles)

    set(handles.pushbutton_print,'Enable','off')
    folder = get_folder();
    set(gcf,'PaperPositionMode','auto')
    print(gcf,'-djpeg','-r600',[folder,'\export_',datestr(now,'yyyymmddHHMMSSFFF'),'.jpg'])
    set(handles.pushbutton_print,'Enable','on')

% ------------------------------------------------------------------------------------------------------------------------
function pushbutton_reset_integrator_Callback(hObject, eventdata, handles)

    reset_integrator

% ------------------------------------------------------------------------------------------------------------------------
function checkbox_freeze_Callback(hObject, eventdata, handles)

    if (get(handles.checkbox_freeze,'Value') == 0)
        axis(handles.axes_y,'auto')
        axis(handles.axes_e,'auto')
        axis(handles.axes_u,'auto')
        axis(handles.axes_integrator,'auto')
        zoom(handles.axes_y,'reset')
        zoom(handles.axes_e,'reset')
        zoom(handles.axes_u,'reset')    
        zoom(handles.axes_integrator,'reset')        
    else
        axis(handles.axes_y,'manual')
        axis(handles.axes_e,'manual')
        axis(handles.axes_u,'manual')
        axis(handles.axes_integrator,'manual')
    end % if

% ------------------------------------------------------------------------------------------------------------------------
function checkbox_limit_Callback(hObject, eventdata, handles)

    global t_limit t_limit_active
    if (get(handles.checkbox_limit,'Value') == 1)
        prompt = {'Please enter the time limit [s]:'};
        dlg_title = 'Time limit';
        num_lines = 1;
        if isempty(t_limit)
            t_limit_default = 20;
        else
            t_limit_default = t_limit;
        end % if
        def = {num2str(t_limit_default)};
        t_limit_txt = inputdlg(prompt,dlg_title,num_lines,def);
        if isempty(t_limit_txt)
            set(handles.checkbox_limit,'Value',0)
            t_limit_active = 0;
            return
        elseif (str2num(t_limit_txt{1}) > 0)
            t_limit = str2num(t_limit_txt{1});
            t_limit_active = 1;
        else
            errordlg('Wrong entry. Time limit will not be changed.');
        end % if
    else
        t_limit_active = 0;
    end % if
    
% ------------------------------------------------------------------------------------------------------------------------
function popupmenu_serial_port_Callback(hObject, eventdata, handles)

    % do not remove this function

% ------------------------------------------------------------------------------------------------------------------------
function popupmenu_baud_rate_Callback(hObject, eventdata, handles)

    % do not remove this function

% ------------------------------------------------------------------------------------------------------------------------
function popupmenu_serial_port_CreateFcn(hObject, eventdata, handles)

    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end

% ------------------------------------------------------------------------------------------------------------------------
function popupmenu_baud_rate_CreateFcn(hObject, eventdata, handles)

    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end

% ------------------------------------------------------------------------------------------------------------------------
function edit_kp_Callback(hObject, eventdata, handles)
    
    if (get_controller_type(handles) == 1) % PID
        send_parameter('kp',handles.edit_kp)
    else
        send_parameter('elower',handles.edit_kp)
    end % if
    
% ------------------------------------------------------------------------------------------------------------------------
function edit_kp_CreateFcn(hObject, eventdata, handles)

    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end

% ------------------------------------------------------------------------------------------------------------------------
function edit_tn_Callback(hObject, eventdata, handles)

    if (get_controller_type(handles) == 1) % PID
        value = str2double(get(handles.edit_tn,'String'));
        if (value == 0)
            set(handles.edit_tn,'ForegroundColor',[0.75,0.75,0.75])
            pos = get(handles.axes_integrator,'Position');
            set(handles.axes_integrator,'Position',[-100,pos(2:4)])
            set(handles.pushbutton_reset_integrator,'Visible','off')
            set(handles.axes_e,'XTickLabelMode','auto');
            xlabel(handles.axes_e,'Time [s]')
        else
            set(handles.edit_tn,'ForegroundColor',[0,0,0])
            pos = get(handles.axes_integrator,'Position');
            set(handles.axes_integrator,'Position',[12.8,pos(2:4)])
            set(handles.pushbutton_reset_integrator,'Visible','on')
            set(handles.axes_e,'XTickLabel',{});
            xlabel(handles.axes_e,'')
        end % if
        send_parameter('tn',handles.edit_tn)
    else
        set(handles.edit_tn,'ForegroundColor',[0,0,0])
        send_parameter('eupper',handles.edit_tn)
    end % if

% ------------------------------------------------------------------------------------------------------------------------
function edit_tn_CreateFcn(hObject, eventdata, handles)

    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end

% ------------------------------------------------------------------------------------------------------------------------
function edit_tv_Callback(hObject, eventdata, handles)

    if (get_controller_type(handles) == 1) % PID
        value = str2double(get(handles.edit_tv,'String'));
        if (value == 0)
            set(handles.edit_tv,'ForegroundColor',[0.75,0.75,0.75])
            set(handles.edit_tf,'Enable','off')
        else
            set(handles.edit_tv,'ForegroundColor',[0,0,0])
            set(handles.edit_tf,'Enable','on')
        end % if
        send_parameter('tv',handles.edit_tv)
    else
        set(handles.edit_tv,'ForegroundColor',[0,0,0])
        send_parameter('ulower',handles.edit_tv)
    end % if

% ------------------------------------------------------------------------------------------------------------------------
function edit_tv_CreateFcn(hObject, eventdata, handles)

    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end

% ------------------------------------------------------------------------------------------------------------------------
function edit_tf_Callback(hObject, eventdata, handles)

    if (get_controller_type(handles) == 1) % PID
        send_parameter('tf',handles.edit_tf)
    else
        send_parameter('uupper',handles.edit_tf)
    end % if        

% ------------------------------------------------------------------------------------------------------------------------
function edit_tf_CreateFcn(hObject, eventdata, handles)

    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end

% ------------------------------------------------------------------------------------------------------------------------
function edit_u_man_r_Callback(hObject, eventdata, handles)

    global signals
    if (signals.automatic(end) == 1)
        send_parameter('r',handles.edit_u_man_r)
    else
        send_parameter('uman',handles.edit_u_man_r)
    end % if

% ------------------------------------------------------------------------------------------------------------------------
function edit_u_man_r_CreateFcn(hObject, eventdata, handles)

    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end

% ------------------------------------------------------------------------------------------------------------------------
function edit_em1_Callback(hObject, eventdata, handles)

    send_parameter('emiddle1',handles.edit_em1)

% ------------------------------------------------------------------------------------------------------------------------
function edit_em1_CreateFcn(hObject, eventdata, handles)

    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end

% ------------------------------------------------------------------------------------------------------------------------
function edit_em2_Callback(hObject, eventdata, handles)

    send_parameter('emiddle2',handles.edit_em2)

% ------------------------------------------------------------------------------------------------------------------------
function edit_em2_CreateFcn(hObject, eventdata, handles)

    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end

% ------------------------------------------------------------------------------------------------------------------------
function edit_um_Callback(hObject, eventdata, handles)

    send_parameter('umiddle',handles.edit_umiddle)

% ------------------------------------------------------------------------------------------------------------------------
function edit_um_CreateFcn(hObject, eventdata, handles)

    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end

% ------------------------------------------------------------------------------------------------------------------------
function edit_dt_Callback(hObject, eventdata, handles)

    send_parameter('dt',handles.edit_dt)

% ------------------------------------------------------------------------------------------------------------------------
function edit_dt_CreateFcn(hObject, eventdata, handles)

    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end

% ------------------------------------------------------------------------------------------------------------------------
function stop_serial_and_timer()

    global obj_serial timr plots

    % Set manual mode and manual output = 0
    if ~isempty(obj_serial)
        try
            send_parameter('manual')
            send_parameter('uman','0')
            pause(1)
        catch exception
            exception_handling(exception)
        end % try
    end % if

    % Stop timer (before closing the serial connection!)
    if ~isempty(timr{1})
        stop(timr{1});
        timr{1} = [];
    end % if

    if ~isempty(timr{2})
        stop(timr{2});
        timr{2} = [];
    end % if

    % Close serial connection
    if ~isempty(obj_serial)
        try
            fclose(obj_serial);
        catch exception
            exception_handling(exception)
        end % try
        obj_serial = [];
    end % if

    plots = {};
    global t_limit t_limit_active
    clear t_limit t_limit_active
    
    export_signals
    
% ------------------------------------------------------------------------------------------------------------------------
function set_auto_or_man(auto_or_man,handles)

    global signals
    send_parameter(auto_or_man)
    switch auto_or_man
        case 'auto'
            set(handles.text_u_man_r,'String','r =')
            set(handles.edit_u_man_r,'String',sprintf('%0.6f',signals.r(end)))
            set(handles.text_e_equals,'Visible','on')
            set(handles.text_e,'Visible','on')
            pos = get(handles.axes_e,'Position');
            set(handles.axes_e,'Position',[12.8,pos(2:4)])
            pos = get(handles.axes_integrator,'Position');
            value = str2double(get(handles.edit_tn,'String'));
            if (get(handles.radiobutton_pid,'Value') ~= 1) || (value == 0)
                set(handles.axes_integrator,'Position',[-100,pos(2:4)])
                set(handles.pushbutton_reset_integrator,'Visible','off')
                set(handles.axes_e,'XTickLabelMode','auto');
                xlabel(handles.axes_e,'Time [s]')
            else
                set(handles.axes_integrator,'Position',[12.8,pos(2:4)])
                set(handles.pushbutton_reset_integrator,'Visible','on')
                set(handles.axes_e,'XTickLabel',{});
                xlabel(handles.axes_e,'')
            end % if
            title(handles.axes_y,'y [rpm] (blue -), r [rpm] (green --)')
            set(handles.edit_kp,'Visible','on')
            set(handles.edit_tn,'Visible','on')
            set(handles.edit_tv,'Visible','on')
            set(handles.edit_tf,'Visible','on')
            set(handles.edit_em1,'Visible','on')
            set(handles.edit_em2,'Visible','on')
            set(handles.edit_um,'Visible','on')
            set(handles.text_kp,'Visible','on')
            set(handles.text_tn,'Visible','on')
            set(handles.text_tv,'Visible','on')
            set(handles.text_tf,'Visible','on')
            set(handles.text_em1,'Visible','on')
            set(handles.text_em2,'Visible','on')
            set(handles.text_um,'Visible','on')
            set(handles.uipanel_controller_type,'Visible','on')
            xlabel(handles.axes_u,'')
            set(handles.axes_u,'XTickLabel',{});
            xlabel(handles.axes_integrator,'Time [s]')
            set_controller_type(get_controller_type(handles),handles)
        case 'manual'
            set(handles.text_u_man_r,'String','u_man =')
            set(handles.edit_u_man_r,'String',sprintf('%0.6f',signals.u_man(end)))
            set(handles.text_e_equals,'Visible','off')
            set(handles.text_e,'Visible','off')
            pos = get(handles.axes_e,'Position');
            set(handles.axes_e,'Position',[-100,pos(2:4)])
            pos = get(handles.axes_integrator,'Position');
            set(handles.axes_integrator,'Position',[-100,pos(2:4)])
            set(handles.pushbutton_reset_integrator,'Visible','off')
            title(handles.axes_y,'y [rpm] (blue -)')           
            set(handles.edit_kp,'Visible','off')
            set(handles.edit_tn,'Visible','off')
            set(handles.edit_tv,'Visible','off')
            set(handles.edit_tf,'Visible','off')
            set(handles.edit_em1,'Visible','off')
            set(handles.edit_em2,'Visible','off')
            set(handles.edit_um,'Visible','off')
            set(handles.text_kp,'Visible','off')
            set(handles.text_tn,'Visible','off')
            set(handles.text_tv,'Visible','off')
            set(handles.text_tf,'Visible','off')
            set(handles.text_em1,'Visible','off')
            set(handles.text_em2,'Visible','off')
            set(handles.text_um,'Visible','off')
            set(handles.uipanel_controller_type,'Visible','off')
            xlabel(handles.axes_u,'Time [s]')
            set(handles.axes_u,'XTickLabelMode','auto');
            reset_integrator
    end % switch

% ------------------------------------------------------------------------------------------------------------------------
function set_controller_type(controller_type,handles)

    switch controller_type
        case {1,'PID'} % PID
            set(handles.radiobutton_pid,'Value',1)
            set(handles.radiobutton_2pc,'Value',0)
            set(handles.radiobutton_3pc,'Value',0)
            set(handles.text_kp,'String','K_P =')
            set(handles.text_tn,'String','T_i =')
            set(handles.text_tv,'String','T_d =')
            set(handles.text_tf,'String','T_f =')
            set(handles.text_em1,'Visible','off')
            set(handles.text_em2,'Visible','off')
            set(handles.text_um,'Visible','off')
            set(handles.edit_em1,'Visible','off')
            set(handles.edit_em2,'Visible','off')
            set(handles.edit_um,'Visible','off')
            value = str2double(get(handles.edit_tn,'String'));
            if (value == 0)
                set(handles.edit_tn,'ForegroundColor',[0.75,0.75,0.75])
                pos = get(handles.axes_integrator,'Position');
                set(handles.axes_integrator,'Position',[-100,pos(2:4)])
                set(handles.pushbutton_reset_integrator,'Visible','off')
                set(handles.axes_e,'XTickLabelMode','auto');
                xlabel(handles.axes_e,'Time [s]')
            else
                set(handles.edit_tn,'ForegroundColor',[0,0,0])
                pos = get(handles.axes_integrator,'Position');
                set(handles.axes_integrator,'Position',[12.8,pos(2:4)])
                set(handles.pushbutton_reset_integrator,'Visible','on')
                set(handles.axes_e,'XTickLabel',{});
                xlabel(handles.axes_e,'')
            end % if
            value = str2double(get(handles.edit_tv,'String'));
            if (value == 0)
                set(handles.edit_tv,'ForegroundColor',[0.75,0.75,0.75])
            else
                set(handles.edit_tv,'ForegroundColor',[0,0,0])
            end % if
            send_parameter('pid')
        case {2,'2PC'} % 2PC
            set(handles.radiobutton_pid,'Value',0)
            set(handles.radiobutton_2pc,'Value',1)
            set(handles.radiobutton_3pc,'Value',0)
            set(handles.text_em1,'Visible','off')
            set(handles.text_em2,'Visible','off')
            set(handles.text_um,'Visible','off')
            set(handles.edit_em1,'Visible','off')
            set(handles.edit_em2,'Visible','off')
            set(handles.edit_um,'Visible','off')
            set(handles.text_kp,'String','e_lo =')
            set(handles.text_tn,'String','e_hi =')
            set(handles.text_tv,'String','u_lo =')
            set(handles.text_tf,'String','u_hi =')
            set(handles.edit_tn,'ForegroundColor',[0,0,0])
            set(handles.edit_tv,'ForegroundColor',[0,0,0])
            pos = get(handles.axes_integrator,'Position');
            set(handles.axes_integrator,'Position',[-100,pos(2:4)])
            set(handles.pushbutton_reset_integrator,'Visible','off')
            set(handles.axes_e,'XTickLabelMode','auto');
            xlabel(handles.axes_e,'Time [s]')
            send_parameter('2pc')
        case {3,'3PC'} % 3PC
            set(handles.radiobutton_pid,'Value',0)
            set(handles.radiobutton_2pc,'Value',0)
            set(handles.radiobutton_3pc,'Value',1)
            set(handles.text_em1,'Visible','on')
            set(handles.text_em2,'Visible','on')
            set(handles.text_um,'Visible','on')
            set(handles.edit_em1,'Visible','on')
            set(handles.edit_em2,'Visible','on')
            set(handles.edit_um,'Visible','on')
            set(handles.text_kp,'String','e_lo =')
            set(handles.text_tn,'String','e_hi =')
            set(handles.text_tv,'String','u_lo =')
            set(handles.text_tf,'String','u_hi =')
            set(handles.edit_tn,'ForegroundColor',[0,0,0])
            set(handles.edit_tv,'ForegroundColor',[0,0,0])
            pos = get(handles.axes_integrator,'Position');
            set(handles.axes_integrator,'Position',[-100,pos(2:4)])
            set(handles.pushbutton_reset_integrator,'Visible','off')
            set(handles.axes_e,'XTickLabelMode','auto');
            xlabel(handles.axes_e,'Time [s]')
            send_parameter('3pc')
    end % switch    

% ------------------------------------------------------------------------------------------------------------------------
function reset_integrator()

    send_parameter('reset')

% ------------------------------------------------------------------------------------------------------------------------
function refresh_figure(handles)

    try
        global path_gui
        if ~strcmp(path_gui,pwd)
            cd(path_gui)
            disp('Please do not change the current folder!')
        end % if

        global signals plots
        set(handles.text_y,'String',sprintf('%0.6f',signals.y(end)))
        set(handles.text_e,'String',sprintf('%0.6f',signals.e(end)))
        set(handles.text_u,'String',sprintf('%0.6f',signals.u_sat(end)))

        global t_limit t_limit_active
        if (t_limit_active) && (get(handles.checkbox_freeze,'Value') == 0)
            idx = find(signals.t >= signals.t(end) - t_limit);
        else
            idx = find(signals.t >= 0);
        end % if
        set(plots{1},'XData',signals.t(idx),'YData',signals.y(idx))
        set(plots{2},'XData',signals.t(idx),'YData',signals.r(idx))
        set(plots{3},'XData',signals.t(idx),'YData',signals.u(idx))
        set(plots{4},'XData',signals.t(idx),'YData',signals.u_sat(idx))
        set(plots{5},'XData',signals.t(idx),'YData',signals.u_max(idx))
        set(plots{6},'XData',signals.t(idx),'YData',signals.u_min(idx))
        set(plots{7},'XData',signals.t(idx),'YData',signals.e(idx))
        set(plots{8},'XData',signals.t(idx),'YData',signals.integrator(idx))

        if (get(handles.checkbox_freeze,'Value') == 0)
            axis(handles.axes_y,'auto')
            axis(handles.axes_e,'auto')
            axis(handles.axes_u,'auto')
            axis(handles.axes_integrator,'auto')
            zoom(handles.axes_y,'reset')
            zoom(handles.axes_e,'reset')
            zoom(handles.axes_u,'reset')
            zoom(handles.axes_integrator,'reset')
            if (t_limit_active)
                xlim(handles.axes_integrator,[max(0,signals.t(end)-t_limit),signals.t(end)]);
            end % if
        else
            axis(handles.axes_y,'manual')
            axis(handles.axes_e,'manual')
            axis(handles.axes_u,'manual')
            axis(handles.axes_integrator,'manual')
        end % if
    catch exception
        exception_handling(exception)
    end % try
    
% ------------------------------------------------------------------------------------------------------------------------
function update_fields(handles)

    global signals
    % Data for text fields and radio buttons
    nn = min(length(signals.ddt)-1,10);
    if any(signals.ddt((end-nn):end)>signals.dt((end-nn):end)+0.1e-3)
        set(handles.edit_dt,'ForegroundColor',[1,0,0]);
    else
        set(handles.edit_dt,'ForegroundColor',[0,0,0]);
    end % if

    if (signals.controller_type(end) == 1) % PID controller
        if new_or_changed(signals.K_P,signals.controller_type)
            set(handles.edit_kp,'String',sprintf('%0.6f',signals.K_P(end)))
        end % if
        if new_or_changed(signals.T_N,signals.controller_type)
            set(handles.edit_tn,'String',sprintf('%0.6f',signals.T_N(end)))
            if (signals.T_N(end) == 0)
                set(handles.edit_tn,'ForegroundColor',[0.75,0.75,0.75])
            else
                set(handles.edit_tn,'ForegroundColor',[0,0,0])
            end % if
        end % if
        if new_or_changed(signals.T_V,signals.controller_type)
            set(handles.edit_tv,'String',sprintf('%0.6f',signals.T_V(end)))
            if (signals.T_V(end) == 0)
                set(handles.edit_tv,'ForegroundColor',[0.75,0.75,0.75])
            else
                set(handles.edit_tv,'ForegroundColor',[0,0,0])
            end % if
        end % if
        if new_or_changed(signals.T_f,signals.controller_type)
            set(handles.edit_tf,'String',sprintf('%0.6f',signals.T_f(end)))
        end % if
        if new_or_changed(signals.controller_type)
            set(handles.text_kp,'String','K_P = ')
            set(handles.text_tn,'String','T_N = ')
            set(handles.text_tv,'String','T_V = ')
            set(handles.text_tf,'String','T_f = ')
            set(handles.radiobutton_pid,'Value',1);
            set(handles.radiobutton_2pc,'Value',0);
            set(handles.radiobutton_3pc,'Value',0);
        end % if
    elseif (signals.controller_type(end) == 2) % 2-position controller
        if new_or_changed(signals.e_lower,signals.controller_type)
            set(handles.edit_kp,'String',sprintf('%0.6f',signals.e_lower(end)))
        end % if
        if new_or_changed(signals.e_upper,signals.controller_type)
            set(handles.edit_tn,'String',sprintf('%0.6f',signals.e_upper(end)))
        end % if
        if new_or_changed(signals.u_lower,signals.controller_type)
            set(handles.edit_tv,'String',sprintf('%0.6f',signals.u_lower(end)))
        end % if
        if new_or_changed(signals.u_upper,signals.controller_type)
            set(handles.edit_tf,'String',sprintf('%0.6f',signals.u_upper(end)))
        end % if
        if new_or_changed(signals.controller_type)                    
            set(handles.text_kp,'String','e_lo = ')
            set(handles.text_tn,'String','e_hi = ')
            set(handles.text_tv,'String','u_lo = ')
            set(handles.text_tf,'String','u_hi = ')
            set(handles.radiobutton_pid,'Value',0);
            set(handles.radiobutton_2pc,'Value',1);
            set(handles.radiobutton_3pc,'Value',0);
        end % if
    elseif (signals.controller_type(end) == 3) % 3-position controller
        if new_or_changed(signals.e_lower,signals.controller_type)
            set(handles.edit_kp,'String',sprintf('%0.6f',signals.e_lower(end)))
        end % if
        if new_or_changed(signals.e_upper,signals.controller_type)
            set(handles.edit_tn,'String',sprintf('%0.6f',signals.e_upper(end)))
        end % if
        if new_or_changed(signals.u_lower,signals.controller_type)
            set(handles.edit_tv,'String',sprintf('%0.6f',signals.u_lower(end)))
        end % if
        if new_or_changed(signals.u_upper,signals.controller_type)
            set(handles.edit_tf,'String',sprintf('%0.6f',signals.u_upper(end)))
        end % if
        if new_or_changed(signals.e_middle1,signals.controller_type)
            set(handles.edit_em1,'String',sprintf('%0.6f',signals.e_middle1(end)))
        end % if
        if new_or_changed(signals.e_middle2,signals.controller_type)
            set(handles.edit_em2,'String',sprintf('%0.6f',signals.e_middle2(end)))
        end % if
        if new_or_changed(signals.u_middle,signals.controller_type)
            set(handles.edit_um,'String',sprintf('%0.6f',signals.u_middle(end)))
        end % if
        if new_or_changed(signals.controller_type)
            set(handles.text_kp,'String','e_lo = ')
            set(handles.text_tn,'String','e_hi = ')
            set(handles.text_tv,'String','u_lo = ')
            set(handles.text_tf,'String','u_hi = ')
            set(handles.text_em1,'String','e_m1 = ')
            set(handles.text_em2,'String','e_m2 = ')
            set(handles.text_um,'String','u_mi = ')
            set(handles.radiobutton_pid,'Value',0);
            set(handles.radiobutton_2pc,'Value',0);
            set(handles.radiobutton_3pc,'Value',1);
        end % if
    end % if

    if (signals.automatic(end) == 1)
        set(handles.edit_u_man_r,'String',sprintf('%0.6f',signals.r(end)))
    else
        if new_or_changed(signals.u_man)
            set(handles.edit_u_man_r,'String',sprintf('%0.6f',signals.u_man(end)))
        end % if
    end % if

    if new_or_changed(signals.dt)
        set(handles.edit_dt,'String',sprintf('%0.6f',signals.dt(end)))
    end % if

    if new_or_changed(signals.automatic)
        if signals.automatic(end)
            set_auto_or_man('auto',handles)
        else
            set_auto_or_man('manual',handles)
        end % if
    end % if

% ------------------------------------------------------------------------------------------------------------------------
function update_plots(handles)

    global signals plots
    if isempty(plots)
        plots{1} = plot(signals.t,signals.y,'Color',[0,0,1],'LineStyle','-','LineWidth',2,'Parent',handles.axes_y);
        hold(handles.axes_y,'on')
        grid(handles.axes_y,'on')
        plots{2} = stairs(signals.t,signals.r,'Color',[0,0.75,0],'LineStyle','--','LineWidth',2,'Parent',handles.axes_y);
        if (signals.automatic(end) == 1)
            title(handles.axes_y,'y [rpm] (blue -), r [rpm] (green --)')
        else
            title(handles.axes_y,'y [rpm] (blue -)')
        end % if
        hold(handles.axes_y,'off')
        set(handles.axes_y,'XTickLabel',{});
        set(handles.axes_y,'YLimMode','auto');
        plots{3} = stairs(signals.t,signals.u,'Color',[1,0.5,0.25],'LineStyle','--','LineWidth',1,'Parent',handles.axes_u);
        hold(handles.axes_u,'on')
        grid(handles.axes_u,'on')
        xlabel(handles.axes_u,'Time [s]')
        plots{4} = stairs(signals.t,signals.u_sat,'Color',[1,0.5,0.25],'LineStyle','-','LineWidth',2,'Parent',handles.axes_u);
        plots{5} = stairs(signals.t,signals.u_max,'Color',[0,0,0],'LineStyle','--','LineWidth',1,'Parent',handles.axes_u);
        plots{6} = stairs(signals.t,signals.u_min,'Color',[0,0,0],'LineStyle','--','LineWidth',1,'Parent',handles.axes_u);
        hold(handles.axes_u,'off')
        title(handles.axes_u,'u [V] (orange --), u_{sat} [V] (orange -), u_{min/max} [V] (black --)')
        plots{7} = plot(signals.t,signals.e,'Color',[1,0,0],'LineStyle','-','LineWidth',2,'Parent',handles.axes_e);
        grid(handles.axes_e,'on')
        title(handles.axes_e,'e [rpm] (red -)')
        set(handles.axes_e,'XTickLabel',{});
        plots{8} = plot(signals.t,signals.integrator,'Color',[0,0,1],'LineStyle','-','LineWidth',2,'Parent',handles.axes_integrator);
        grid(handles.axes_integrator,'on')
        title(handles.axes_integrator,'Integrator [rpm*s] (blue -)')
        linkaxes([handles.axes_y,handles.axes_e,handles.axes_u,handles.axes_integrator],'x');
        zoom(handles.figure1,'on')
    end % if


% ------------------------------------------------------------------------------------------------------------------------
function getData(obj_serial,handles)
    
    try
        persistent data0 verbose
        if ~exist('obj_serial','var') % initialization
            data0 = [];
            return
        end % if
        global signals signal_names plots timr exception

        n0 = obj_serial.BytesAvailable;
        if (n0 > 0)
            data0 = [data0,char(fread(obj_serial,n0))'];
            n1 = regexp(data0,'/B/','once');
            if (~isempty(n1))
                n2 = strfind(data0((n1(1)+3):end),'/E/')+n1(1)+2;
                if (~isempty(n2)>0)
                    data = data0((n1(1)+3):(n2(1)-1));
                    data0 = data0((n2(1)+4):end);
                end % if
            end % if
        end % if

        if exist('data','var')
            if (verbose >= 2)
                fprintf('%s\n',data)
            end % if
            try
                binary = 1;
                if binary
                    raw = double(typecast(uint8(data),'single'));
                else
                    raw = cellfun(@str2num,regexp(data,',','split')');
                end % if            
            catch exception
                raw = [];
                exception_handling(exception)
            end % try
            if (length(raw) == length(signal_names))
                if (~isempty(signals.t)) && (raw(1) < signals.t(end))
                    warning('Restart')
                    signals = clear_signals;
                    plots = {};
                    stop(timr{1})
                    stop(timr{2})
                    pause(1)
                    start(timr{1})
                    start(timr{2})
                end % if

                % Data for logging
                signals = assign_signals(signals,raw);
                if (signals.automatic(end) == 0)
                    signals.r(end) = NaN;
                    signals.e(end) = NaN;
                end % if

                update_fields(handles)
                update_plots(handles)

                if (length(signals.dt)>1)&&(signals.dt(end) ~= signals.dt(end-1)) % dt has changed --> timer has to be set to new sampling rate
                    stop(timr{1});
                    dt_timer = max(0.001,round(0.6*signals.dt(end)*1000)/1000);
                    timr{1} = timer('TimerFcn', @(x,y)getData(obj_serial,handles), 'Period', dt_timer);
                    set(timr{1},'ExecutionMode','fixedRate');
                    start(timr{1});
                end % if
            end % if
        end % if
    catch exception
        exception_handling(exception)
    end % try    
    
% ------------------------------------------------------------------------------------------------------------------------
function set_enable(handles,status)
        
    set(handles.pushbutton_reset_integrator,'Enable',status)
    set(handles.radiobutton_auto,'Enable',status)
    set(handles.radiobutton_manual,'Enable',status)
    set(handles.radiobutton_pid,'Enable',status)
    set(handles.radiobutton_2pc,'Enable',status)
    set(handles.radiobutton_3pc,'Enable',status)
    set(handles.edit_kp,'Enable',status)
    set(handles.edit_tn,'Enable',status)
    set(handles.edit_tv,'Enable',status)
    %set(handles.edit_tf,'Enable',status)
    set(handles.edit_em1,'Enable',status)
    set(handles.edit_em2,'Enable',status)
    set(handles.edit_um,'Enable',status)
    set(handles.edit_u_man_r,'Enable',status)
    %set(handles.edit_dt,'Enable',status)
    set(handles.pushbutton_export,'Enable',status)
    set(handles.pushbutton_print,'Enable',status)
    set(handles.checkbox_freeze,'Enable',status)
    set(handles.checkbox_limit,'Enable',status)

% ------------------------------------------------------------------------------------------------------------------------
function signals = clear_signals()
        
    global signal_names
    for count = 1:length(signal_names)
        eval(['signals.',signal_names{count},' = [];'])
    end % for

% ------------------------------------------------------------------------------------------------------------------------
function signals = assign_signals(signals,raw)

    global signal_names
    if (length(raw) ~= length(signal_names))
        error('Incompatible dimensions.')
    else
        for count = 1:length(signal_names)
            eval(['signals.',signal_names{count},'(end+1,1) = raw(',num2str(count),');'])
        end % for
    end % if

% ------------------------------------------------------------------------------------------------------------------------
function noc = new_or_changed(varargin)

if (nargin == 1)
    y = varargin{1};
    noc = (length(y)==1)||(y(end)~=y(end-1));
else
    y = varargin{1};
    controller_type = varargin{2};
    noc = (length(y)==1)||(y(end)~=y(end-1))||(controller_type(end)~=controller_type(end-1));
end % if

% ------------------------------------------------------------------------------------------------------------------------
function controller_type = get_controller_type(handles)

    get(get(handles.uipanel_controller_type,'SelectedObject'),'String');
    
    if get(handles.radiobutton_pid,'Value')
        controller_type = 1;
    elseif get(handles.radiobutton_2pc,'Value')
        controller_type = 2;
    else
        controller_type = 3;
    end % if

% ------------------------------------------------------------------------------------------------------------------------
function send_parameter(str,value)

    global obj_serial verbose
    if (~exist('value','var'))
        fprintf(obj_serial,'%s\n',str);
        if (verbose >= 1)
            fprintf('%s\n',str);
        end % if
    else
        if ishandle(value)
            fprintf(obj_serial,sprintf('%s=%0.6f\n',str,str2double(get(value,'String'))));
            if (verbose >= 1)
                fprintf(sprintf('%s=%0.6f\n',str,str2double(get(value,'String'))));
            end % if
        elseif isa(value,'char')
            fprintf(obj_serial,sprintf('%s=%0.6f\n',str,str2double(value)));
            if (verbose >= 1)
                fprintf(sprintf('%s=%0.6f\n',str,str2double(value)));
            end % if
        else            
            fprintf(obj_serial,sprintf('%s=%0.6f\n',str,value));
            if (verbose >= 1)
                fprintf(sprintf('%s=%0.6f\n',str,value));
            end % if
        end % if
    end % if

% ------------------------------------------------------------------------------------------------------------------------
function export_signals()
        
    global signals signal_names
    signal = signals;
    if ~isempty(signal_names)
        folder = get_folder();
        save([folder,'\export_',datestr(now,'yyyymmddHHMMSSFFF'),'.mat'],'signal')
        str = ['csvwrite([''',folder,'\export_'',datestr(now,''yyyymmddHHMMSSFFF''),''.csv''],['];
        for count = 1:length(signal_names)
            str = [str, 'signals.', signal_names{count}, ','];
        end % for
        str = [str(1:(end-1)), '])'];
        eval(str);
    end % for
    
% ------------------------------------------------------------------------------------------------------------------------
function lCOM_Port = getAvailableComPort() % Return a Cell Array of COM port names available on your computer

    try
        fopen(serial('IMPOSSIBLE_NAME_ON_PORT'));
    catch exception
        lErrMsg = lasterr;
    end
    lIndex1 = findstr(lErrMsg,'COM'); % Start of the COM available port
    lIndex2 = findstr(lErrMsg,'Use')-3; % End of COM available port
    lComStr = lErrMsg(lIndex1:lIndex2);
    lIndexDot = findstr(lComStr,','); % Parse the resulting string
    if isempty(lIndex1) % If no ports are available
        lCOM_Port{1} = '';
        return
    end
    if isempty(lIndexDot) % If only one port is available
        lCOM_Port{1} = lComStr;
        return
    end
    lCOM_Port{1} = lComStr(1:lIndexDot(1)-1);
    for i = 1:(numel(lIndexDot)+1)
        if (i==1) % First one
            lCOM_Port{1,1} = lComStr(1:lIndexDot(i)-1);
        elseif (i==numel(lIndexDot)+1) % Last one
            lCOM_Port{i,1} = lComStr(lIndexDot(i-1)+2:end);       
        else % Others
            lCOM_Port{i,1} = lComStr(lIndexDot(i-1)+2:lIndexDot(i)-1);
        end
    end    

% ------------------------------------------------------------------------------------------------------------------------
function exception_handling(exception)

    disp(exception.message)
    disp(exception.stack(1))
    folder = '.\Exceptions';
    if ~exist(folder,'dir')
        mkdir(folder)
    end % if
    save([folder,'\exception_',datestr(now,'yyyymmddHHMMSSFFF'),'.mat'],'exception')
    
% ------------------------------------------------------------------------------------------------------------------------
function [folder] = get_folder()

    folder = '.\Export';
    if ~exist(folder,'dir')
        mkdir(folder)
    end % if

% ------------------------------------------------------------------------------------------------------------------------
function populate_popup_menus(handles,str)
    
    % Populate pop-up menu for serial port
    if ispc % PC
        ports = getAvailableComPort; % define manually if problems occur
        %ports = {'COM5'};
    elseif ismac % MAC
        warning('Operating system is MAC.') % --> define manually as stated below
        % ports = {'/dev/tty.usbmodemfa121','/dev/tty.usbmodemfa131'} % {'/dev/ttyS0','/dev/tty.KeySerial1'};
    elseif isunix % Linux or Unix
        warning('Operating system is Linux or Unix.') % --> define manually as stated below
        %ports = {'/dev/ttyS0','/dev/tty.KeySerial1'};
    else
        warning('Operating system could not be recognized.')
    end % if
    if exist('str','var')
        ports{end+1} = str;
    end % if
    set(handles.popupmenu_serial_port,'String',ports)
    set(handles.popupmenu_serial_port,'Value',max(1,min(3,length(ports))))

    % Populate pop-up menu for baud rate
    set(handles.popupmenu_baud_rate,'String',{'115200'})
    set(handles.popupmenu_baud_rate,'Value',1)
    set(handles.popupmenu_baud_rate,'Visible','off')
    set(handles.text_baud_rate,'Visible','off')

% ------------------------------------------------------------------------------------------------------------------------
function selection_auto_man(hObject, eventdata)

    handles = guidata(hObject);
    txt = get(get(hObject,'SelectedObject'),'String');
    set_auto_or_man(txt,handles)
    
% ------------------------------------------------------------------------------------------------------------------------
function selection_controller_type(hObject, eventdata)

    handles = guidata(hObject);
    txt = get(get(hObject,'SelectedObject'),'String');
    set_controller_type(txt,handles)

% ------------------------------------------------------------------------------------------------------------------------
function characteristic_curve()

    global signals
    u_man = signals.u_man(end);
    u_min = signals.u_min(end);
    u_max = signals.u_max(end);
    dt = signals.dt(end);
    
    prompt = {'Enter low input [V]:','Enter high input [V]:','Enter number of points [-]:','Enter step duration per point [s]:'};
    dlg_title = 'Characteristic Curve';
    num_lines = 1;
    def = {num2str(u_min),num2str(u_max),'21','20'};
    answer = inputdlg(prompt,dlg_title,num_lines,def);
    if isempty(answer)
        return
    else
        u_min = str2double(answer{1});
        u_max = str2double(answer{2});
        N = str2double(answer{3});
        T = str2double(answer{4});
        global uvec yvec
        uvec = linspace(u_min,u_max,N)';
        yvec = zeros(size(uvec));
        for count = 1:N
            u = uvec(count);
            fprintf('Point no. %2d of %2d: %6.2f V ',count,N,u)
            send_parameter('uman',num2str(u))
            if (count == 1) % wait longer after first point
                pause(2*T)
            end % if
            pause(T)
            idx = find(signals.t>signals.t(end)-0.1*T);
            y = mean(signals.y(idx));
            fprintf('--> %6.2f rpm\n',y)
            yvec(count) = y;
        end % for
        send_parameter('uman',num2str(u_man))
        figure
        plot(uvec,yvec,'b.-')
        grid on
        title('Characteristic Curve')
        xlabel('u [V]')
        ylabel('y [rpm]')
    end % if
    
% ------------------------------------------------------------------------------------------------------------------------
function frequency_response_old()

    global signals
    dt = signals.dt(end);

    u_amplitude = 10;
    u_frequency = 0.03; % Hz
    T_period = 1/u_frequency;
    t0 = signals.t(end);
    t = signals.t(end)-t0;
    while (t < 3*T_period)
        u_man = u_amplitude*sin(2*pi*u_frequency*t);
        send_parameter('uman',num2str(u_man))
        %fprintf('%.2f\t%.2f\n',t,u_man);
        pause(10*dt);
        t = signals.t(end)-t0;
    end % while        
    send_parameter('uman',num2str(0))
    
% ------------------------------------------------------------------------------------------------------------------------
function frequency_response(handles)

    prompt = {'Enter low frequency [Hz]:','Enter high frequency [Hz]:','Number of points [-]','Number of periods (min. 3) [-]','Enter offset [V]:','Enter amplitude [V]:','Enter time constant [s]'};
    dlg_title = 'Frequency Response';
    num_lines = 1;
    def = {'0.1','1.0','3','3','6','5','6'};
    answer = inputdlg(prompt,dlg_title,num_lines,def);
    if isempty(answer)
        return
    else
        fr_frequency_low = str2double(answer{1});
        fr_frequency_high = str2double(answer{2});
        fr_number_of_points = str2double(answer{3});
        if (fr_frequency_high ~= fr_frequency_low)
            fr_number_of_points = max(fr_number_of_points,2);
        else
            fr_number_of_points = 1;
        end % if        
        fr_periods = max(3,str2double(answer{4}));
        fr_offset = str2double(answer{5});
        fr_amplitude = str2double(answer{6});
        fr_time_constant = str2double(answer{7});
        fr_span = logspace(log10(fr_frequency_low),log10(fr_frequency_high),fr_number_of_points);
        controller_type_previous = get_controller_type(handles);
        global signals
        count = 0;
        for fr_frequency = fr_span
            count = count + 1;
            fprintf('Point no. %2d of %2d: %6.2f Hz ',count,fr_number_of_points,fr_frequency)
            send_parameter('fr_offset',fr_offset)
            send_parameter('fr_amplitude',fr_amplitude)
            send_parameter('fr_frequency',fr_frequency)
            send_parameter('freqresp')            
            pause(5*fr_time_constant)
            pause(fr_periods/fr_frequency)
            idx1 = (signals.t > signals.t(end) - fr_periods/fr_frequency);
            idx2 = ((signals.t > signals.t(end) - (fr_periods+0.5)/fr_frequency) & (signals.t <= signals.t(end) - 0.5/fr_frequency));
            t = signals.t(idx1);
            u1 = (signals.u(idx1)-fr_offset);
            u2 = (signals.u(idx2)-fr_offset);
            y = signals.y(idx1);
            im = trapz(t,u1.*y)/fr_periods/fr_amplitude^2;
            re = trapz(t,u2.*y)/fr_periods/fr_amplitude^2;
            
            x = signals;
            A = 0;
            phi = 0;
            fprintf('--> %6.2f rpm/V, %6.2f° \n',A,phi)
            % figure,plot(t,u),hold on,plot(t,y,'r'),plot(t,u.*y,'g'), grid on
            % figure, plot(u,y,'.'), axis equal
        end % for
        send_parameter('man')
        set_controller_type(controller_type_previous,handles)
    end % if    
    
% ------------------------------------------------------------------------------------------------------------------------
function manual_send()

    prompt = {'Enter manual command:'};
    dlg_title = 'Manual command';
    num_lines = 1;
    def = {''};
    answer = inputdlg(prompt,dlg_title,num_lines,def);
    if isempty(answer)
        return
    else
        global obj_serial
        str = answer{1};
        fprintf(obj_serial,'%s\n',str);    
    end % if
    
% ------------------------------------------------------------------------------------------------------------------------
function watch_keypress(hObject, eventdata, handles)
    
    if (strcmp(eventdata.Character,'c'))&&(length(eventdata.Modifier)==1)&&any(strcmp(eventdata.Modifier,'alt'))        
        if strcmp(get(handles.pushbutton_connect,'String'),'Disconnect')
            characteristic_curve
        end % if
    elseif (strcmp(eventdata.Character,'f'))&&(length(eventdata.Modifier)==1)&&any(strcmp(eventdata.Modifier,'alt'))        
        if strcmp(get(handles.pushbutton_connect,'String'),'Disconnect')
            frequency_response(handles)
        end % if
    elseif (strcmp(eventdata.Character,'m'))&&(length(eventdata.Modifier)==1)&&any(strcmp(eventdata.Modifier,'alt'))        
        if strcmp(get(handles.pushbutton_connect,'String'),'Disconnect')
            manual_send
        end % if
    end % if
