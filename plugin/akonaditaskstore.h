#pragma once

#include "taskstore.h"

class AkonadiTaskStore : public AbstractTaskStore
{
    Q_OBJECT

public:
    explicit AkonadiTaskStore(QObject *parent = nullptr);

    void submit(const Request &request) override;

private:
    void runModify(const Request &request);
    void runMove(const Request &request);
    void runCreate(const Request &request);
    void runDelete(const Request &request);
    void emitResult(Result result);
};
