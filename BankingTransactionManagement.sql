
CREATE TABLE Accounts (
    Account_ID NUMBER PRIMARY KEY,
    Account_Name VARCHAR2(100),
    Balance NUMBER(15, 2) DEFAULT 0,
    Created_Date DATE DEFAULT SYSDATE
);

-- Table for transactions
CREATE TABLE Transactions (
    Transaction_ID NUMBER PRIMARY KEY,
    From_Account_ID NUMBER,
    To_Account_ID NUMBER,
    Amount NUMBER(15, 2),
    Transaction_Date DATE DEFAULT SYSDATE
);


CREATE OR REPLACE FUNCTION Get_Balance(p_account_id NUMBER) RETURN NUMBER IS
    v_balance NUMBER;
BEGIN
    SELECT Balance INTO v_balance
    FROM Accounts
    WHERE Account_ID = p_account_id;

    RETURN v_balance;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20001, 'Account not found.');
END Get_Balance;
/


CREATE OR REPLACE PROCEDURE Add_Account(
    p_account_id NUMBER,
    p_account_name VARCHAR2,
    p_initial_balance NUMBER
) AS
BEGIN
    INSERT INTO Accounts (Account_ID, Account_Name, Balance)
    VALUES (p_account_id, p_account_name, p_initial_balance);

    DBMS_OUTPUT.PUT_LINE('Account created successfully: ' || p_account_name);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error creating account: ' || SQLERRM);
END Add_Account;
/


CREATE OR REPLACE PROCEDURE Transfer_Funds(
    p_from_account_id NUMBER,
    p_to_account_id NUMBER,
    p_amount NUMBER
) AS
    v_from_balance NUMBER;
    v_to_balance NUMBER;
BEGIN
    -- Step 1: Check source account balance
    v_from_balance := Get_Balance(p_from_account_id);

    IF v_from_balance < p_amount THEN
        RAISE_APPLICATION_ERROR(-20002, 'Insufficient funds in source account.');
    END IF;

    -- Step 2: Deduct amount from source account
    UPDATE Accounts
    SET Balance = Balance - p_amount
    WHERE Account_ID = p_from_account_id;

    -- Step 3: Add amount to destination account
    UPDATE Accounts
    SET Balance = Balance + p_amount
    WHERE Account_ID = p_to_account_id;

    -- Step 4: Log the transaction
    INSERT INTO Transactions (Transaction_ID, From_Account_ID, To_Account_ID, Amount)
    VALUES ((SELECT NVL(MAX(Transaction_ID), 0) + 1 FROM Transactions), p_from_account_id, p_to_account_id, p_amount);

    -- Step 5: Commit transaction
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Funds transferred successfully.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error transferring funds: ' || SQLERRM);
END Transfer_Funds;
/


CREATE OR REPLACE PROCEDURE View_Statement(p_account_id NUMBER) AS
BEGIN
    DBMS_OUTPUT.PUT_LINE('Transaction History for Account ID: ' || p_account_id);
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------');
    FOR rec IN (
        SELECT * FROM Transactions
        WHERE From_Account_ID = p_account_id OR To_Account_ID = p_account_id
        ORDER BY Transaction_Date
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('Transaction ID: ' || rec.Transaction_ID || ', From: ' || rec.From_Account_ID || ', To: ' || rec.To_Account_ID || ', Amount: ' || rec.Amount || ', Date: ' || rec.Transaction_Date);
    END LOOP;
END View_Statement;
/


CREATE OR REPLACE TRIGGER Prevent_Negative_Balance
BEFORE UPDATE OF Balance ON Accounts
FOR EACH ROW
BEGIN
    IF :NEW.Balance < 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Account balance cannot be negative.');
    END IF;
END Prevent_Negative_Balance;
/


CREATE TABLE Account_Audit_Log (
    Audit_ID NUMBER PRIMARY KEY,
    Account_ID NUMBER,
    Account_Name VARCHAR2(100),
    Initial_Balance NUMBER,
    Created_Date DATE DEFAULT SYSDATE
);

CREATE OR REPLACE TRIGGER Log_Account_Creation
AFTER INSERT ON Accounts
FOR EACH ROW
BEGIN
    INSERT INTO Account_Audit_Log (Audit_ID, Account_ID, Account_Name, Initial_Balance, Created_Date)
    VALUES ((SELECT NVL(MAX(Audit_ID), 0) + 1 FROM Account_Audit_Log), :NEW.Account_ID, :NEW.Account_Name, :NEW.Balance, :NEW.Created_Date);
END Log_Account_Creation;
/

BEGIN
    Add_Account(1, 'John Doe', 10000);
    Add_Account(2, 'Jane Smith', 5000);
END;
/

BEGIN
    Transfer_Funds(1, 2, 2000);
END;
/

BEGIN
    View_Statement(1);
END;
/

-- View accounts
SELECT * FROM Accounts;

-- View transactions
SELECT * FROM Transactions;

-- View account audit log
SELECT * FROM Account_Audit_Log;
