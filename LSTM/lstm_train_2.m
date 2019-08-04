Kfold = 10;%设置交叉检验折数
indices = crossvalind('Kfold',csi_label,Kfold);%划分训练集和测试集
%[x_train, y_train,  x_test, y_test] = split_train_test(csi_train, csi_label, 6, 0.7);
saveDir = 'G:\无源感知研究\实验结果\2019_08_04_实验室\';

for i = 1:Kfold
    %划分此次的训练集和测试集
    test = (indices == i); 
    train = ~test;
    x_train = csi_train(train);
    y_train = csi_label(train);
    x_test = csi_train(test);
    y_test = csi_label(test);
    
    %对训练集进行排序
    [x_train,y_train] = sequenceSort(x_train,y_train);
    
    %训练网络
    net = trainLSTM(x_train,y_train,x_test,y_test);
    
    %时间戳
    nowtime = fix(clock);
    nowtimestr = sprintf('%d-%d-%d-%d-%d-%d',nowtime(1),nowtime(2),nowtime(3),nowtime(4),nowtime(5),nowtime(6));
    
    %保存网络
    networkSaveDir = sprintf('%s%s%d%s%s',saveDir,'network(',i,')-',nowtimestr);
    save(networkSaveDir,'net');
    
    %预测并计算准确率
    y_Pred = classify(net,x_test, 'SequenceLength','longest');
    acc = sum(y_Pred == y_test)./numel(y_test)
    acc_count(i) = acc;
    
    %绘制混淆矩阵
    figure('Units','normalized','Position',[0.2 0.2 0.4 0.4]);
    cm = confusionchart(y_test,y_Pred);
    cm.Title = 'Confusion Matrix for Validation Data';
    cm.ColumnSummary = 'column-normalized';
    cm.RowSummary = 'row-normalized';
    
    %保存混淆矩阵
    confusionchartSaveDir = sprintf('%s%s%d%s%s',saveDir,'confusionchart(',i,')-',nowtimestr);
    saveas(gcf,confusionchartSaveDir);
    saveas(gcf,strcat(confusionchartSaveDir,'.jpg'));
end

function [x_train,y_train] = sequenceSort(x_train,y_train)
    numObservations = numel(x_train);
    for i=1:numObservations
        sequence = x_train{i};
        sequenceLengths(i) = size(sequence,2);
    end

    [~,idx] = sort(sequenceLengths);
    x_train = x_train(idx);
    y_train = y_train(idx);
end

function net = trainLSTM(x_train,y_train,x_test,y_test)
    inputSize = 180;
    numHiddenUnits = 128;
    numClasses = 6;

    layers = [ ...
        sequenceInputLayer(inputSize)
        bilstmLayer(100,'OutputMode','sequence')
        dropoutLayer(0.2)
        bilstmLayer(numHiddenUnits,'OutputMode','last')
        dropoutLayer(0.2)
        fullyConnectedLayer(numClasses)
        softmaxLayer
        classificationLayer];

    maxEpochs = 360;
    miniBatchSize = 32;

    options = trainingOptions('adam', ...
        'ExecutionEnvironment','auto', ...
        'GradientThreshold',1, ...
        'MaxEpochs',maxEpochs, ...
        'MiniBatchSize',miniBatchSize', ...
        'SequenceLength','longest', ...
        'Verbose',0, ...
        'ValidationData',{x_test,y_test}, ...
        'ValidationFrequency',5, ...
        'LearnRateSchedule', 'piecewise', ...
    	'LearnRateDropFactor', 0.8, ...
        'LearnRateDropPeriod', 20, ...
        'Plots','training-progress');

    net = trainNetwork(x_train,y_train,layers,options);
end